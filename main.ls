require! <[request cheerio fs]>

fetchlist = (id, cb, param) ->
  (e,r,b) <- request do
    url: "http://www.mobile01.com/topiclist.php?f=356&p=#id"
    headers:
      "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.124 Safari/537.36"
  $ = cheerio.load b
  posts = $("table[summary='文章列表'] > tbody > tr")
  posts = posts.map (i,e) ->
    title = $(e).find("td.subject > .subject-text > a").text!
    link = $(e).find("td.subject > .subject-text > a").attr("href")
    reply = parseInt($(e).find("td.reply").text!)
    time = $(e).find("td.authur > a > p:first-of-type").text!
    pid = /t=(\d+)$/.exec title
    if !pid => pid = 0
    else pid = pid.1
    {title, link, reply, time, pid}
  cb posts, param

findlength = (callback) ->
  bs2 = (plist, {L,R}) ->
    if plist.length => L = parseInt(( L + R ) / 2) + 1
    else R = parseInt(( L + R ) / 2)
    if L >= R => callback R
    else fetchlist parseInt((L+R)/2), bs2, {L,R}
  bs = (L, R) ->
    console.log "locate between: #L #R"
    fetchlist parseInt((L+R)/2), bs2, {L, R}
  cb = (plist, id) -> 
    console.log '>>>', id
    if plist.length => fetchlist id * 2, cb , id * 2
    else bs id, id*2
  fetchlist 1, cb, 1

fetchpost = (start) ->
  return
  cb = (plist, page) ->
    if !plist.length =>
      if page > 1 => fetchlist page - 1, cb, page - 1
      else => return
    item = plist.splice(0,1)
    if fs.exists-sync "raw/#{item.pid}" => return cb plist, page
    (e,r,b) <- request do
      url: "http://www.mobile01.com#{item.link}"
      headers: "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.124 Safari/537.36"
    fs.write-file-sync "raw/#{item.pid}", b
    cb plist, page
  fetchlist start, cb, start

(len) <- findlength
console.log "total: #len"
cb = (plist, {L,R}) ->
  item = plist[* - 1]
  if fs.exists-sync "raw/#{item.pid}" => R = parseInt((L + R)/2)
  else L = parseInt((L + R)/2) + 1
  if L >= R => fetchpost L
  else => fetchlist parseInt((L + R)/2), cb, {L,R}

fetchlist parseInt((1 + len)/2), cb, {1, len}
