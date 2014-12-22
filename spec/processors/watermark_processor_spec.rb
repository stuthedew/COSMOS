# encoding: ascii-8bit

# Copyright � 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/processors/watermark_processor'

module Cosmos

  describe WatermarkProcessor do

    describe "initialize" do
      it "should take an item_name and value_type" do
        p = WatermarkProcessor.new('TEST', 'RAW')
        p.value_type.should eql :RAW
        p.instance_variable_get("@item_name").should eql 'TEST'
      end
    end

    describe "call and reset" do
      it "should generate a high and low water mark" do
        p = WatermarkProcessor.new('TEST', 'RAW')
        packet = Packet.new("tgt","pkt")
        packet.append_item("TEST", 8, :UINT)
        packet.buffer= "\x01"
        p.call(packet, packet.buffer)
        p.results[:HIGH_WATER].should eql 1
        p.results[:LOW_WATER].should eql 1
        packet.buffer= "\x02"
        p.call(packet, packet.buffer)
        p.results[:HIGH_WATER].should eql 2
        p.results[:LOW_WATER].should eql 1
        packet.buffer= "\x00"
        p.call(packet, packet.buffer)
        p.results[:HIGH_WATER].should eql 2
        p.results[:LOW_WATER].should eql 0
        p.reset
        p.results[:HIGH_WATER].should eql nil
        p.results[:LOW_WATER].should eql nil
      end
    end
  end
end

