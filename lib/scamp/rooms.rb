class Scamp
  module Rooms
    # TextMessage (regular chat message),
    # PasteMessage (pre-formatted message, rendered in a fixed-width font),
    # SoundMessage (plays a sound as determined by the message, which can be either "rimshot", "crickets", or "trombone"),
    # TweetMessage (a Twitter status URL to be fetched and inserted into the chat)

    def upload
    end

    def room_id(room_id_or_name)
      if room_id_or_name.is_a? Integer
        return room_id_or_name
      else
        return room_id_from_room_name(room_id_or_name)
      end
    end
    
    def room_name_for(room_id)
      data = room_cache_data(room_id)
      return data["name"] if data
      room_id.to_s
    end

    def join_room(id)
      connect_to_room(id) do
        fetch_room_data(id)
        stream(id)
      end
    end
    
    private
    
    def room_cache_data(room_id)
      return room_cache[room_id] if room_cache.has_key? room_id
      fetch_room_data(room_id)
      return false
    end
    
    def populate_room_list
      url = "https://#{subdomain}.campfirenow.com/rooms.json"
      http = EventMachine::HttpRequest.new(url).get :head => {'authorization' => [api_key, 'X']}
      http.errback { logger.error "Couldn't connect to url #{url} to fetch room list" }
      http.callback {
        if http.response_header.status == 200
          logger.debug "Fetched room list"
          new_rooms = {}
          Yajl::Parser.parse(http.response)['rooms'].each do |c|
            new_rooms[c["name"]] = c
          end
          # No idea why using the "rooms" accessor here doesn't
          # work but accessing the ivar directly does. There's
          # Probably a bug.
          @rooms = new_rooms # replace existing room list
          yield if block_given?
        else
          logger.error "Couldn't fetch room list with url #{url}, http response from API was #{http.response_header.status}"
        end
      }
    end

    def connect_to_room(room_id)
      logger.info "Connecting to room #{room_id}"
      url = "https://#{subdomain}.campfirenow.com/room/#{room_id}/join.json"
      http = EventMachine::HttpRequest.new(url).post :head => {'Content-Type' => 'application/json', 'authorization' => [api_key, 'X']}
      
      http.errback { logger.error "Error joining room: #{room_id}" }
      http.callback {
        logger.info "Joined room #{room_id} successfully"
        Room.new(self, room_id, method(:process_message))
      }
    end

    def room_id_from_room_name(room_name)
      logger.debug "Looking for room id for #{room_name}"
      rooms[room_name]["id"]
    end
  end
end
