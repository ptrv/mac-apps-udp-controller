#!/usr/bin/env ruby

# Mac apps UDP controller script.
#
# Control OSX application with messages received via UDP.
#
# Author: Peter Vasil <p.vasil@gmail.com>
# Date: 29 February 2012
#

# require "rubygems"
require 'socket'
require 'ipaddr'

#############################################################################
## checking for commandline options
##############################################################################
$broadcast_port = 5555
$broadcast_ip = "239.255.0.1"

$simulation = false
$debug_print = false
$presentation_mode = false
$current_app = 0
if ARGV.include? "debug"
  $debug_print = true
end
if ARGV.include? "presentation"
  $presentation_mode = true
end
if $presentation_mode
  $current_app = 1
end
if ARGV.include? "simulation"
  $simulation = true
end

#############################################################################
## global variables
##############################################################################
$apps = ["iTunes","Keynote", "iTunes", "VLC", "iTunes"]
$last_time = Time.now.to_f
$delta_time = 0.0
$last_time2 = Time.now.to_f
$msg_types = ["triangle", "pinch", "finger"]
$msg_buffer = []
$gesture_buffer = []
if $simulation
  $num_to_buffer = 3
  $num_same_msgs = 2
else
  $num_to_buffer = 10
  $num_same_msgs = 7
end

#############################################################################
# UPD listener
#############################################################################
class UDPServer
  def initialize(multicast_addr, port)
    @multicast_addr = multicast_addr
    @port = port
  end

  def start
    # http://onestepback.org/index.cgi/Tech/Ruby/MulticastingInRuby.red
    ip =  IPAddr.new(@multicast_addr).hton + IPAddr.new("0.0.0.0").hton
    @socket = UDPSocket.new
    @socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, ip)
    @socket.bind(Socket::INADDR_ANY, @port)
    loop do
      packet = @socket.recvfrom(1024)
      dispatch_packet(packet[0])
      if $debug_print
        packetinfo = packet[1].join(',')
        puts packet[0] + " -> info:[" + packetinfo + "]"
      end
    end
  end
end

#############################################################################
# AppleScript functions
#############################################################################
def next_song()
  %x[osascript -e 'tell application "iTunes"\nnext track\nend tell']
end

def prev_song()
  %x[osascript -e 'tell application "iTunes"\nprevious track\nend tell']
end

def playpause()
  %x[osascript -e 'tell application "iTunes"\nplaypause\nend tell']
end

def play()
  %x[osascript -e 'tell application "iTunes"\nplay\nend tell']
end

def stop()
  %x[osascript -e 'tell application "iTunes"\nstop\nend tell']
end

def set_volume(val)
  %x[osascript -e 'tell application "iTunes"\nset the sound volume to #{val}\nend tell']
end

def start_slideshow()
  %x[osascript -e 'tell application "Keynote"\ntell slideshow 1\nstart\nend tell\nend tell']
end

$slideshow_running = false
def startstop_slideshow()
  if $startswitch
    $startswitch = true
    stop_slideshow
  else
    $startswitch = false
    start_slideshow
  end
end

def stop_slideshow
  %x[osascript -e 'tell application "Keynote"\ntell slideshow 1\nstop slideshow\nend tell\nend tell']
end

def next_slide()
  %x[osascript -e 'tell application "Keynote"\nshow next\nend tell']  
end

def prev_slide()
  %x[osascript -e 'tell application "Keynote"\nshow previous\nend tell']  
end

def activate_app(app_number)
   %x[osascript -e 'tell application "#{$apps[app_number-1]}"\nactivate\nend tell'] 
end

def vlc_playpause
  %x[osascript -e 'tell application "VLC"\nplay\nend tell']
end

def vlc_next
  %x[osascript -e 'tell application "VLC"\nnext\nend tell']
end

def vlc_prev
  %x[osascript -e 'tell application "VLC"\nprevious\nend tell']
end

#############################################################################
# Pinch direction calculation
#############################################################################
def get_pinch_dir(msgs)
  sumX = 0
  sumY = 0
  lastX = 0.0
  lastY = 0.0
  isFirst = true
  msgs.each do |m|
    if m[1] == "pinch"
      if isFirst == true
        lastX = m[2].to_f
        lastY = m[3].to_f
        isFirst = false
      end
      sumX += m[2].to_f - lastX
      sumY += m[3].to_f - lastY
      lastX = m[2].to_f
      lastY = m[3].to_f
    end
  end
  if $simulation
    threshold = 0
  else
    threshold = 15
  end
  if sumX.abs > sumY.abs
    if sumX > threshold
      dir = "right"
    elsif sumX < -threshold
      dir = "left"
    else
      dir = "NOPE"
    end
  elsif sumX.abs < sumY.abs
    if sumY > threshold
      dir = "down"
    elsif sumY < -threshold
      dir = "up"
    else
      dir = "NOPE"
    end
  end
  # puts sumX.to_s + " " + sumY.to_s 
  return dir
end

#############################################################################
## filter function for receiving messages
##############################################################################
def get_message_for_use(msg)
  # unless $msg_buffer.empty?
  #   tn = Time.now.to_f
  #   dt = tn - $last_time2
  #   $last_time2 = tn
  #   if(dt > 0.5)
  #     $msg_buffer.clear
  #     $gesture_buffer.clear
  #   end
  # end

  $msg_buffer.push(msg[1])
  $gesture_buffer.push(msg)

  # puts msg
  if $msg_buffer.length > $num_to_buffer
    # count messages in array and return hash 
    # with key = frequency and value = message
    b = $msg_buffer.inject(Hash.new(0)) {|h,i| h[i] += 1; h }
    # sort messages according frequency -> first highest
    c = b.sort_by {|k,v| v}.reverse
    # c.each  do |k,v|
    #   puts "#{k} #{v}"      
    # end

    # use messge only if more than 7 out of 10
    if c.to_a[0][1] > $num_same_msgs
      # get index of message with highest frequency
      index_of_last = $msg_buffer.rindex(c.to_a[0][0])
      # get message from message array
      msg_to_send = $gesture_buffer[index_of_last]
      # if pinch -> calculate direction
      dir = "NOPE"
      if msg_to_send[1] == "pinch"
         dir = get_pinch_dir($gesture_buffer)
         msg_to_send.push(dir)
         # puts msg_to_send
      end
      $msg_buffer.clear
      $gesture_buffer.clear
      return msg_to_send
    end
  end
  return nil
end

# def should_use_message(msg)
#   if $last_msg == msg and $same_count < 5
#     # puts "last was same"
#     $same_count += 1
#     return false
#   else
#     $same_count = 0
#     $msg_buffer.clear
#     return true
#   end
# end

#############################################################################
## dispatch messages after filtering
##############################################################################
def dispatch_packet(msg)
  message = msg.split(';')
  # if message[1] == "NOPE"
  #   return  
  # end
  msg2 = get_message_for_use(message)
  unless msg2.nil?
    if msg2[1] == "triangle"
      process_triangle(msg2[2].to_i)
    elsif msg2[1] == "fingercount"
      process_fingercount(msg2[2].to_i)
    elsif msg2[1] == "pinch"
      process_pinch_coords(msg2[2].to_f, msg2[3].to_f, msg2[4].to_f,msg2[5].to_s)
    end
  end
end

#############################################################################
## process gestures
##############################################################################
def process_triangle(size)
  unless $presentation_mode
    set_volume(size)
  end
end

def process_fingercount(finger)
  unless $presentation_mode
    unless finger == 1
      # if current_app == 1 and $startswitch == true
      #   startstop_slideshow
      # end
      if $current_app == 1 and $slideshow_running == true
        stop_slideshow
      end 
      activate_app(finger)
      $current_app = finger-1
    end
  end
end

def process_pinch_coords(x, y, z, dir)
  tn = Time.now.to_f
  dt = tn - $last_time
  $last_time = tn
  $delta_time += dt 
  # this is for not letting pinch event fire to often
  if($delta_time > 1.0)
    $delta_time = 0.0

    if $current_app == 1 # Keynote
      if dir == "right"
        next_slide
      elsif dir == "left"
        prev_slide
      elsif dir == "up"
        startstop_slideshow
      end
    elsif $current_app == 2 # iTunes
      if dir == "right"
        next_song
      elsif dir == "left"
        prev_song
      elsif dir == "up"
        playpause
      end
    elsif $current_app == 3 # VLC
      if dir == "right"
        vlc_next
      elsif dir == "left"
        vlc_prev
      elsif dir == "up"
        vlc_playpause
      end
    end
  end
end

#############################################################################
## Start UDP listener
##############################################################################
server = UDPServer.new($broadcast_ip, $broadcast_port)
begin
server.start
rescue Interrupt
end
