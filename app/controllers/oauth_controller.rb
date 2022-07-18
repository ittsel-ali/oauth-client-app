class OauthController < ApplicationController
  before_action :set_auth_client
  
  def new
    @code_verifier = SecureRandom.hex(22)
    @code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@code_verifier), padding: false)
  end

  def auth
    # Step 1: Generate Authentication URl
    auth_url = @client.auth_code.authorize_url(redirect_uri: ENV['APP_CALLBACK_URI'], scope: "read write", code_challenge: params[:code_challenge], code_challenge_method: "S256")
    
    ####### resulting url #######
    # http://localhost:3000/oauth/authorize?client_id=uY9cxCR_KBcH7PGaCVFkPZ8hhVqv3DdFd5g0ciLZ6dI
    # &code_challenge=444a545674bfdc7e13a64fc5a30760a5&code_challenge_method=plain&redirect_uri=http%3A%2F%2Flocalhost%3A3001%2Foauth%2Fcallback
    # &response_type=code&scope=read+write
    ####### resulting url #######

    session[:code_verifier] = params[:code_verifier]
    
    # Step 2 (1st handshake): Redirect to server login page to generate access_token against user session and get code
    redirect_to auth_url
  end

  def callback
  end

  def continue_callback
    # Step 3: Backend call (2nd handshake) to Auth server to get access_token (jwt), additional request params include `code` received at Step 2
    # and `code_verifier` which will be verified by the auth server
    @token = @client.auth_code.get_token(params[:code], redirect_uri: ENV['APP_CALLBACK_URI'], code_verifier: session[:code_verifier])
    @token_payload = JWT.decode @token.token, nil, false
  end



  def refresh_token
    url = URI(ENV['AUTH_SERVER_URL'])

    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Post.new(url)
    request["content-type"] = 'application/x-www-form-urlencoded'
    request["cache-control"] = 'no-cache'
    request.body = "grant_type=refresh_token&refresh_token=#{params[:refresh_token]}&client_id=#{ENV['APP_ID']}&client_secret=#{ENV['APP_SECRET']}"

    response = http.request(request)
    @data = response.read_body
  end

  def get_campaign_info
    # URI of trader server
    url = URI(ENV['AUTH_SERVER_URL'])

    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Post.new(url)
    request["authorization"] = "Bearer #{params[:token]}"
    request["content-type"] = 'application/json'

    # GraphQL query string
    request.body = grapqhl_query
    response = http.request(request)
    @data = response.read_body
  end 

  private

  def set_auth_client
    # Step 0: Setup OAuth client with App ID, App Secret registered in Auth server and `site` url of Auth searver
    @client = OAuth2::Client.new(ENV['APP_ID'], ENV['APP_SECRET'], site: ENV['AUTH_SERVER_URL'])
  end

  def permit_params
    params.permit!
  end

  def grapqhl_query
    "{     \"operationName\":\"GetCampaigns\",     \"variables\":{},     
      \"query\":
        \"query GetCampaigns 
          {\ 
            campaigns 
            { 
              data 
              {
                id
                name
                state
                life_stage
                start_at
                end_at
                bid_tactic
              }  
              __typename\ 
            }
          \\n}
        \\n\"   
      }"
  end
end


