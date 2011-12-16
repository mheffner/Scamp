class Scamp
  class Room

    def initialize(context, room_id, msg_cb)
      @ctxt = context
      @id = room_id
      @msg_handler = msg_cb

      fetch_room_data

      EM::Timer.new(5) do
        puts "leaving"
        leave
      end
    end

  private

    def fetch_room_data
      url = "https://#{@ctxt.subdomain}.campfirenow.com/room/#{@id}.json"

      http = @ctxt.http_req(url, :get, {})

      http.errback {
        @ctxt.logger.error "Couldn't fetch room data for room #{@id}"
      }

      http.callback {
        if http.response_header.status == 200
          room = Yajl::Parser.parse(http.response)['room']
          @ctxt.room_cache[room["id"]] = room

          room['users'].each do |u|
            @ctxt.update_user_cache_with(u["id"], u)
          end

          stream
        else
          @ctxt.logger.error "Couldn't fetch room data for room %s: %s" %
            [@id, http.response_header.status]
        end
      }
    end

    def stream
      json_parser = Yajl::Parser.new :symbolize_keys => true
      json_parser.on_parse_complete = @msg_handler

      http = http_stream
      http.errback {
        @ctxt.logger.error "Couldn't stream room: #{@id}."
      }
      http.callback {
        @ctxt.logger.info "Disconnected from room: #{@id}"
        @ctxt.rooms_to_join << @id
      }

      http.stream {|chunk| json_parser << chunk }
    end

    def leave
      url = "https://#{@ctxt.subdomain}.campfirenow.com/room/#{@id}/leave.json"

      http = @ctxt.http_req(url, :post, {},
                            {'Content-Type' => 'application/json'})
      http.errback {
        @ctxt.logger.error "Error leaving room: #{@id}"
      }
      http.callback {
        @ctxt.logger.info "Left room #{@id} successfully: #{http.response_header.status}"
      }
    end

    def http_stream
      url = "https://streaming.campfirenow.com/room/#{@id}/live.json"
      # Timeouts per:
      # https://github.com/igrigorik/em-http-request/wiki/Redirects-and-Timeouts
      opts = {:connect_timeout => 20, :inactivity_timeout => 0}

      @ctxt.http_req(url, :get, opts)
    end
  end
end
