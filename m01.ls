require! <[fs cheerio request]>

ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.124 Safari/537.36"
httpheader = "User-Agent": ua
if !fs.exists-sync('config') => fs.mkdir-sync 'config'
if fs.exists-sync 'config/m01' => config = JSON.parse(fs.read-file-sync 'config/m01' .toString!)
else => config = {}
if !config.date => config.date = new Date(0)

if !fs.exists-sync 'raw' => fs.mkdir-sync 'raw'
if !fs.exists-sync 'raw/m01' => fs.mkdir-sync 'raw/m01'
if !fs.exists-sync 'chk' => fs.mkdir-sync 'chk'
if !fs.exists-sync 'chk/m01' => fs.mkdir-sync 'chk/m01'

save-config = -> fs.write-file-sync 'config/m01', JSON.stringify(config)
fetchlist = (id, cb, param) ->
  <- setTimeout _, 1500
  (e,r,b) <- request do
    url: "http://www.mobile01.com/topiclist.php?f=356&p=#id"
    headers: httpheader
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

fetchpost = (start) ->
  console.log "last post at page #start"
  cb = (plist, page) ->
    if !plist.length =>
      if page > 1 => fetchlist page - 1, cb, page - 1
      else => console.log "done."
      return
    item = plist.splice(0,1).0
    #console.log item.link
    if config["#{item.pid}"] => return cb plist, page
    #if postmanager.exists item.pid => return cb plist, page
    console.log "fetch: page #page / item #{item.pid}"
    <- setTimeout _, 1500
    #console.log item.link
    (e,r,b) <- request do
      url: "http://www.mobile01.com/#{item.link}"
      headers: httpheader
    if e => console.log "error: failed to get entry #{item.pid} (#{item.link})"
    $ = cheerio.load b
    title = $('main > h1.topic').text!
    date = $('main > article:first-of-type .single-post-author .inner .date').text!
    date = /(\d+)-(\d+)-(\d+) (\d+):(\d+)/.exec date
    date = new Date(date.1, date.2, date.3, date.4, date.5)
    content = $('main > article:first-of-type .single-post-content > div:first-of-type').text!
    content = content.replace /\r\n/g, "\n"
    prefix = "#{item.pid}".substring(0,3)
    postfix = "#{item.pid}".substring(3)
    if !(fs.exists-sync "raw/m01/#prefix") => fs.mkdir-sync "raw/m01/#prefix"
    fs.write-file-sync "raw/m01/#prefix/#postfix", "#title\n\n#content"
    if !(fs.exists-sync "chk/m01/#prefix") => fs.mkdir-sync "chk/m01/#prefix"
    fs.write-file-sync "chk/m01/#prefix/#postfix", "#title\n\n#content"
    config.date = date
    config["#{item.pid}"] = 1
    save-config!
    cb plist, page
  fetchlist start, cb, start

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

fetch-post-date = (item, cb) ->
  <- setTimeout _, 1500
  (e,r,b) <- request do
    url: "http://www.mobile01.com/#{item.link}"
    headers: httpheader
  if e => console.log "error: failed to get entry #{item.pid} (#{item.link})"
  $ = cheerio.load b
  title = $('main > h1.topic').text!
  date = $('main > article:first-of-type .single-post-author .inner .date').text!
  date = /(\d+)-(\d+)-(\d+) (\d+):(\d+)/.exec date
  date = new Date(date.1, date.2, date.3, date.4, date.5)
  cb date

fetch-page-date = (page, cb) ->
  <- setTimeout _, 1500
  (e,r,b) <- request do
    url: "http://www.mobile01.com/topiclist.php?f=356&p=#page"
    headers: httpheader
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
  fetch-post-date posts.0, cb

find-last-fetch = (date,L,R,cb) ->
  if L>=R => return cb L - 1
  M = parseInt((L + R) / 2)
  (d) <- fetch-page-date M
  console.log "page #M: #d"
  if date > d => R := M
  else L := M + 1
  setTimeout (-> find-last-fetch date, L, R, cb), 0

(len) <- findlength
(page) <- find-last-fetch config.date, 1, len, _
fetchpost page
#console.log page

#findlength -> console.log it
/*fetchpost 710
(len) <- findlength
cb = (plist, {L,R}) ->
  console.log "[last fetch] search between #L and #R"
  item = plist[* - 1]

  #if postmanager.exists item.pid => R = parseInt((L + R)/2)
  if config["#{item.pid}"] => R = parseInt((L + R)/2)
  else L = parseInt((L + R)/2) + 1
  if L >= R => fetchpost L
  else => fetchlist parseInt((L + R)/2), cb, {L,R}

fetchlist parseInt((1 + len)/2), cb, {L: 1, R: len}
*/
