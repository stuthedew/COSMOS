#!/usr/bin/env ruby
# encoding: ascii-8bit

# Copyright � 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

def autohotkey(command_name, ahk_script = nil)
  Dir.chdir(File.join(File.expand_path(File.dirname(__FILE__)), '..', '..'))
  require "./spec/spec_helper.rb"

  # Set the user path to our COSMOS configuration in the autohotkey directory
  Cosmos::USERPATH.replace File.join(File.expand_path(File.dirname(__FILE__)), '..')

  SimpleCov.command_name command_name

  if ahk_script
    Thread.new do
      `AutoHotKey.exe #{File.join(File.expand_path(File.dirname(__FILE__)), ahk_script)}`
    end
  end

  yield
  sleep(2)

  # Clean up CTS log files
  Dir["autohotkey/outputs/logs/*"].each do |file|
    next if File.basename(file) == "cmd.bin" || File.basename(file) == "tlm.bin" ||
      File.basename(file) == "bigtlm.bin"
    File.delete file
  end
end

