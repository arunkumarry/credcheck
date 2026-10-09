class Rack::Attack
  # Rate limit API endpoints to 5 requests per minute per IP address
  throttle('req/ip/api', limit: 5, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/') && req.post?
      req.ip
    end
  end

  # Return 429 Too Many Requests
  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'RateLimit-Limit' => match_data[:limit].to_s,
      'RateLimit-Remaining' => '0',
      'RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s,
      'Content-Type' => 'application/json'
    }

    [ 429, headers, [{ error: "Rate limit exceeded. Try again later." }.to_json] ]
  end
end
