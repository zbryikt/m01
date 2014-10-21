require! <[request cheerio fs]>

if !fs.exists-sync("raw") => fs.mkdir-sync "raw"
postmanager = do
  write: (id, data) -> 
    p = @path id
    if !fs.exists-sync("raw/#{p.1}") => fs.mkdir-sync("raw/#{p.1}")
    fs.write-file-sync p.0, data
  exists: (id) -> fs.exists-sync @path(id).0
  path: (id) ->
    id = "#id"
    prefix = id.substring(0,2)
    postfix = id.substring(2)
    return ["raw/#prefix/#postfix", prefix, postfix]

fetchlist = (id, cb, param) ->
  <- setTimeout _, 1500
  (e,r,b) <- request do
    url: "http://www.mobile01.com/topiclist.php?f=356&p=#id"
    headers:
      "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.124 Safari/537.36"
  $ = cheerio.load b
  posts = []
  _posts = $("table[summary='文章列表'] > tbody > tr")
  _posts.map (i,e) ->
    title = $(e).find("td.subject > .subject-text > a").text!
    link = $(e).find("td.subject > .subject-text > a").attr("href")
    reply = parseInt($(e).find("td.reply").text!)
    time = $(e).find("td.authur > a > p:first-of-type").text!
    pid = /t=(\d+)$/.exec link
    if !pid => pid = 0
    else pid = pid.1
    if link => posts.push {title, link, reply, time, pid}
  cb posts, param

findlength = (callback) ->
  bs2 = (plist, {L,R}) ->
    console.log "[length] test between #L and #R"
    if plist.length => L = parseInt(( L + R ) / 2) + 1
    else R = parseInt(( L + R ) / 2)
    if L >= R => callback R
    else fetchlist parseInt((L+R)/2), bs2, {L,R}
  bs = (L, R) ->
    console.log "locate between: #L #R"
    fetchlist parseInt((L+R)/2), bs2, {L, R}
  cb = (plist, id) -> 
    console.log "[length] test: #id"
    if plist.length => fetchlist id * 2, cb , id * 2
    else bs id/2, id
  fetchlist 1, cb, 1

fetchpost = (start) ->
  console.log "last post at page #start"
  cb = (plist, page) ->
    if !plist.length =>
      if page > 1 => fetchlist page - 1, cb, page - 1
      else => console.log "done."
      return
    item = plist.splice(0,1).0
    if postmanager.exists item.pid => return cb plist, page
    #if fs.exists-sync "raw/#{item.pid}" => return cb plist, page
    console.log "fetch: page #page / item #{item.pid}"
    <- setTimeout _, 1500
    (e,r,b) <- request do
      url: "http://www.mobile01.com/#{item.link}"
      headers: "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.124 Safari/537.36"
    if e => console.log "error: failed to get entry #{item.pid} (#{item.link})"
    $ = cheerio.load b
    title = $('main > h1.topic').text!
    content = $('main > article:first-of-type .single-post-content > div:first-of-type').text!
    content = content.replace /\r\n/g, "\n"
    postmanager.write item.pid, "#title\n#{'='*30}\n#content"
    #fs.write-file-sync "raw/#{item.pid}", "#title\n#{'='*30}\n#content"
    cb plist, page
  fetchlist start, cb, start

fetchpost 710
/*
(len) <- findlength
console.log "total: #len"
cb = (plist, {L,R}) ->
  console.log "[last fetch] search between #L and #R"
  item = plist[* - 1]
  #if fs.exists-sync "raw/#{item.pid}" => R = parseInt((L + R)/2)
  if postmanager.exists item.pid => R = parseInt((L + R)/2)
  else L = parseInt((L + R)/2) + 1
  if L >= R => fetchpost L
  else => fetchlist parseInt((L + R)/2), cb, {L,R}

fetchlist parseInt((1 + len)/2), cb, {L: 1, R: len}

*/
