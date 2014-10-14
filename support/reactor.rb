
# fucking TCPServer gives us TCPSocket which doesn't have a non-blocking read

require "socket"

include Socket::Constants
socket = Socket.new(AF_INET, SOCK_STREAM, 0)
socket.setsockopt(:SOCKET, :REUSEADDR, true)
sockaddr = Socket.sockaddr_in(9998, '0.0.0.0')


socket.bind(sockaddr)
socket.listen(5)

# block
#client, client_addrinfo = socket.accept

#client, client_addrinfo = socket.accept_nonblock

# we should distinguish readable and writable streams 
read_array = []
# 

loop do
  begin # emulate blocking accept
    # make a listening structure
    j = {} 
    j[:action] = :listening
    j[:socket] = socket
    j[:client],j[:client_addrinfo] = j[:socket].accept_nonblock
    read_array << j
    puts "0 read array length #{read_array.length}"

  rescue IO::WaitReadable, Errno::EINTR
    x = IO.select( [j[:socket] ] )

    x[0].each do |socket| 
      puts "affected socket #{socket}"
      puts "1 read_array length #{read_array.length}"
      #now look it up in the list
      j = read_array.detect  {|y| puts "ysock #{y[:socket]}" }

      puts "j is #{j}"

      if j && j[:action] = :listening
        puts "here"

        # it seems like these actions have to be done in the main array ? 
        m = {} 
        m[:action] = :reading
        m[:socket] = j[:client]
        m[:data] = j[:client].recvfrom_nonblock(20)
        read_array << j 

        puts "here"
      end
    end

    retry
  end
end
  
