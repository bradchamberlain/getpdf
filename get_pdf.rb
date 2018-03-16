require 'net/http'
require 'uri'
require 'json'
require 'httparty'
require 'base64'
require 'pry'

class Pdf 

  REQUEST_OPTIONS = {
    use_ssl: true,
  }
  SPLITS = [["\n","\\n"],["\r\n","\\r\\n"]]    

  def initialize args
    print "Environment: "
    @environment = send args[0]
    @filename = args[1] || "xml.xml"
    @output_file = args[2] || "cert.pdf"
  end

  def dev
    puts "DEV"
    {
      host: "https://api-dev.octanner.net",
      key: "",
      secret: ""
    }
  end

  def qa
    puts "QA"
    {
      host: "https://api-qa.octanner.net",
      key:  "",
      secret: ""
    }
  end

  def token
    puts "Getting token"
    uri = URI.parse("#{@environment[:host]}/auth/oauth/v2/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(@environment[:key], @environment[:secret])
    request.content_type = "application/x-www-form-urlencoded"
    request.set_form_data(
      "grant_type" => "client_credentials",
    )
     
    response = Net::HTTP.start(uri.hostname, uri.port, REQUEST_OPTIONS) do |http|
      http.request(request)
    end
     
    token = JSON.parse(response.body)
  end

  def headers 
    puts "BUILDING HEADERS"
    {
      'Authorization' => "Bearer #{token["access_token"]}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/pdf'
    }
  end

  def body
    puts "reading #{@filename} for #{@environment[:host]}"

    b = File.read(@filename)
    SPLITS.each do |t|
      b = b.split(t[0]).join(t[1])
    end
    b
  end

  def write_pdf response
    puts "WRITING PDF"
    decoded = Base64.decode64(response.body)
    File.open(@output_file, "wb") do |f|
      f.write(decoded)
    end
    puts "Wrote #{@output_file}"
  end

  def getPdf 
    puts "GETTING PDF" 

    response = HTTParty.post("#{@environment[:host]}/xpression/documents", headers: headers, body: JSON.parse(body).to_json)
    if response.code == 200
      write_pdf response
    else
      puts response.code
      puts response.body
    end
  end
end

if ARGV.length == 0 || !%w[dev qa].include?(ARGV[0])
  puts "USAGE [dev|qa](required) input_file_name(optional) output_file_name(optional)"
  return
else
  pdf = Pdf.new  ARGV
  pdf.getPdf
end
