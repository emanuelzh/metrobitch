require 'json'
require 'twitter'
require 'mysql2'
require 'time'

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ""
  config.consumer_secret     = ""
  config.access_token        = ""
  config.access_token_secret = ""
end

#make the dir
system('mkdir '+ARGV[0].to_s)

first_time = true
all_tweets = []
max_id = 0

#mysql
conn = Mysql2::Client.new(:host => "localhost", :username => "bitch", :password => "metrobitch*",
	:database=>"metrobitch", :encoding=>"utf8mb4")

pst = conn.prepare("INSERT INTO 
tweets(twitter_id, likes, retweets, responses, created_at, content, type, permalink) 
VALUES(?,?,?,?,?,?,'tweet',?)")

#retrieve first
loop do

	if first_time
		tweets = client.user_timeline(ARGV[0].to_s, count: 200, tweet_mode: "extended")
		max_id = tweets[tweets.size - 1].id
		first_time = false
	else
		tweets = client.user_timeline(ARGV[0].to_s, count: 200, max_id: max_id, tweet_mode: "extended")
		max_id = tweets[tweets.size - 1].id
	end

	puts "Tamaño: "+tweets.size.to_s

	tweets.each do |tw|
		puts tw.uri
		puts tw.id
		#pst.execute "sasda"
		if tw.truncated? && tw.attrs[:extended_tweet]
		  # Streaming API, and REST API default
		  t = tw.attrs[:extended_tweet][:full_text]
		else
		  # REST API with extended mode, or untruncated text in Streaming API
		  t = tw.attrs[:text] || tw.attrs[:full_text]
		end
		puts t

		#date
		#cool_date = Time.parse(tw.created_at).strftime("%F %T")
		c_date = tw.created_at.dup.utc
		cool_date = c_date.strftime("%F %T")

		#puts tw.reply_count
		replies = 0

		#insert into db
		begin
			pst.execute(tw.id,tw.favorite_count,tw.retweet_count,replies,cool_date,t.force_encoding('UTF-8'),tw.uri.to_s)
		rescue
			next
		end
		File.open(ARGV[0].to_s+'/'+tw.id.to_s+'.json','w') { |file| file.write(JSON.generate(tw.to_h))}

		if tw.uris?
			tw.uris.each do |uri|
				puts uri.to_s
			end
		end

		if tw.media?
			puts tw.media
			#puts "trae media --"
			tw.media.each do |media|
				if media.instance_of? Twitter::Media::Photo 
					#puts media.media_url
					system('wget '+media.media_url+' -O '+ARGV[0].to_s+'/'+media.id.to_s+'.jpg')
				end

				if media.instance_of? Twitter::Media::Video
					puts media.inspect
					#system('wget '+media.media_url+' -O '+ARGV[0].to_s+'/vid_'+media.id.to_s+'.jpg')
				end

				if media.instance_of? Twitter::Media::AnimatedGif
					#puts media.media_url
					#system('wget '+media.media_url+' -O '+ARGV[0].to_s+'/gif_'+media.id.to_s+'.jpg')
				end
			end
		end

	end

	break if tweets.size < 199
end

conn.close
pst.close
