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
require 'cosmos/packets/binary_accessor'

module Cosmos

  describe BinaryAccessor do

    describe "read" do

      before(:each) do
        @data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
      end

      it "should complain about unrecognized data types" do
        lambda { BinaryAccessor.read(0, 32, :BLOB, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "data_type BLOB is not recognized")
      end

      it "should complain about bit_offsets before the beginning of the buffer" do
        lambda { BinaryAccessor.read(-((@data.length * 8) + 8), 32, :STRING, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "#{@data.length} byte buffer insufficient to read STRING at bit_offset #{-((@data.length * 8) + 8)} with bit_size 32")
      end

      it "should complain about a negative bit_offset and zero bit_size" do
        lambda { BinaryAccessor.read(-8, 0, :STRING, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "negative or zero bit_sizes (0) cannot be given with negative bit_offsets (-8)")
      end

      it "should complain about a negative bit_offset and negative bit_size" do
        lambda { BinaryAccessor.read(-8, -8, :STRING, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "negative or zero bit_sizes (-8) cannot be given with negative bit_offsets (-8)")
      end

      it "should complain about negative bit_sizes larger than the size of the buffer" do
        lambda { BinaryAccessor.read(0, -((@data.length * 8) + 8), :STRING, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "#{@data.length} byte buffer insufficient to read STRING at bit_offset 0 with bit_size #{-((@data.length * 8) + 8)}")
      end

      it "should complain about negative or zero bit_sizes with data_types other than STRING and BLOCK" do
        lambda { BinaryAccessor.read(0, -8, :INT, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "bit_size -8 must be positive for data types other than :STRING and :BLOCK")
        lambda { BinaryAccessor.read(0, -8, :UINT, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "bit_size -8 must be positive for data types other than :STRING and :BLOCK")
        lambda { BinaryAccessor.read(0, -8, :FLOAT, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "bit_size -8 must be positive for data types other than :STRING and :BLOCK")
      end

      it "should read aligned strings" do
        0.step((@data.length - 1) * 8, 8) do |bit_offset|
          if (bit_offset / 8) <= 7
            BinaryAccessor.read(bit_offset, (@data.length * 8) - bit_offset, :STRING, @data, :BIG_ENDIAN).should eql(@data[(bit_offset / 8)..7])
          elsif (bit_offset / 8) == 8
            BinaryAccessor.read(bit_offset, (@data.length * 8) - bit_offset, :STRING, @data, :BIG_ENDIAN).should eql('')
          else
            BinaryAccessor.read(bit_offset, (@data.length * 8) - bit_offset, :STRING, @data, :BIG_ENDIAN).should eql(@data[(bit_offset / 8)..-1])
          end
        end
      end

      it "should read variable length strings with a zero and negative bit_size" do
        0.step(-(@data.length * 8), -8) do |bit_size|
          if (bit_size / 8) >= -8
            BinaryAccessor.read(0, bit_size, :STRING, @data, :BIG_ENDIAN).should eql(@data[0..7])
          else
            BinaryAccessor.read(0, bit_size, :STRING, @data, :BIG_ENDIAN).should eql(@data[0..((bit_size / 8) - 1)])
          end
        end
      end

      it "should read strings with negative bit_offsets" do
        BinaryAccessor.read(-16, 16, :STRING, @data, :BIG_ENDIAN).should eql(@data[-2..-1])
      end

      it "should complain about unaligned strings" do
        lambda { BinaryAccessor.read(1, 32, :STRING, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "bit_offset 1 is not byte aligned for data_type STRING")
      end

      it "should read aligned blocks" do
        0.step((@data.length - 1) * 8, 8) do |bit_offset|
          BinaryAccessor.read(bit_offset, (@data.length * 8) - bit_offset, :BLOCK, @data, :BIG_ENDIAN).should eql(@data[(bit_offset / 8)..-1])
        end
      end

      it "should read variable length blocks with a zero and negative bit_size" do
        0.step(-(@data.length * 8), -8) do |bit_size|
          BinaryAccessor.read(0, bit_size, :BLOCK, @data, :BIG_ENDIAN).should eql(@data[0..((bit_size / 8) - 1)])
        end
      end

      it "should read blocks with negative bit_offsets" do
        BinaryAccessor.read(-16, 16, :BLOCK, @data, :BIG_ENDIAN).should eql(@data[-2..-1])
      end

      it "should complain about unaligned blocks" do
        lambda { BinaryAccessor.read(7, 16, :BLOCK, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "bit_offset 7 is not byte aligned for data_type BLOCK")
      end

      it "should complain if read exceeds the size of the buffer" do
        lambda { BinaryAccessor.read(8, 800, :STRING, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "16 byte buffer insufficient to read STRING at bit_offset 8 with bit_size 800")
      end

      it "should read aligned 8-bit unsigned integers" do
        0.step((@data.length - 1) * 8, 8) do |bit_offset|
          BinaryAccessor.read(bit_offset, 8, :UINT, @data, :BIG_ENDIAN).should eql(@data.getbyte(bit_offset / 8))
        end
      end

      it "should read aligned 8-bit signed integers" do
        0.step((@data.length - 1) * 8, 8) do |bit_offset|
          expected = @data.getbyte(bit_offset / 8)
          expected = expected - 256 if expected >= 128
          BinaryAccessor.read(bit_offset, 8, :INT, @data, :BIG_ENDIAN).should eql(expected)
        end
      end

      describe "given big endian data" do

        it "should read 1-bit unsigned integers" do
          expected = [0x1, 0x0]
          bit_size = 1
          BinaryAccessor.read(8, bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(9, bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read 1-bit signed integers" do
          expected = [0x1, 0x0]
          bit_size = 1
          BinaryAccessor.read(8, bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(9, bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read 7-bit unsigned integers" do
          expected = [0x40, 0x02]
          bit_size = 7
          BinaryAccessor.read(8, bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(3, bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read 7-bit signed integers" do
          expected = [0x40, 0x02]
          bit_size = 7
          expected.each_with_index { |value, index| expected[index] = value - 2**bit_size if value >= 2**(bit_size - 1) }
          BinaryAccessor.read(8, bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(3, bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read 13-bit unsigned integers" do
          expected = [0x1C24, 0x20]
          bit_size = 13
          BinaryAccessor.read(30, bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(1,  bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read 13-bit signed integers" do
          expected = [0x1C24, 0x20]
          bit_size = 13
          expected.each_with_index { |value, index| expected[index] = value - 2**bit_size if value >= 2**(bit_size - 1) }
          BinaryAccessor.read(30, bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(1,  bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read aligned 16-bit unsigned integers" do
          expected_array = [0x8081, 0x8283, 0x8485, 0x8687, 0x0009, 0x0A0B, 0x0C0D, 0x0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 16) do |bit_offset|
            BinaryAccessor.read(bit_offset, 16, :UINT, @data, :BIG_ENDIAN).should eql(expected_array[index])
            index += 1
          end
        end

        it "should read aligned 16-bit signed integers" do
          expected_array = [0x8081, 0x8283, 0x8485, 0x8687, 0x0009, 0x0A0B, 0x0C0D, 0x0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 16) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**16 if expected >= 2**15
            BinaryAccessor.read(bit_offset, 16, :INT, @data, :BIG_ENDIAN).should eql(expected)
            index += 1
          end
        end

        it "should read aligned 32-bit unsigned integers" do
          expected_array = [0x80818283, 0x84858687, 0x00090A0B, 0x0C0D0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 32) do |bit_offset|
            BinaryAccessor.read(bit_offset, 32, :UINT, @data, :BIG_ENDIAN).should eql(expected_array[index])
            index += 1
          end
        end

        it "should read aligned 32-bit signed integers" do
          expected_array = [0x80818283, 0x84858687, 0x00090A0B, 0x0C0D0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 32) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**32 if expected >= 2**31
            BinaryAccessor.read(bit_offset, 32, :INT, @data, :BIG_ENDIAN).should eql(expected)
            index += 1
          end
        end

        it "should read aligned 32-bit floats" do
          expected_array = [-1.189360e-038, -3.139169e-036, 8.301067e-040, 1.086646e-031]
          BinaryAccessor.read(0,  32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-038).of(expected_array[0])
          BinaryAccessor.read(32, 32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-036).of(expected_array[1])
          BinaryAccessor.read(64, 32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-040).of(expected_array[2])
          BinaryAccessor.read(96, 32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-031).of(expected_array[3])
        end

        it "should read 37-bit unsigned integers" do
          expected = [0x8182838485 >> 3, 0x00090A0B0C]
          bit_size = 37
          BinaryAccessor.read(8,  bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(67, bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read 37-bit signed integers" do
          expected = [0x8182838485 >> 3, 0x00090A0B0C]
          bit_size = 37
          expected.each_with_index { |value, index| expected[index] = value - 2**bit_size if value >= 2**(bit_size - 1) }
          BinaryAccessor.read(8,  bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(67, bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read 63-bit unsigned integers" do
          expected = [0x8081828384858687 >> 1, 0x00090A0B0C0D0E0F]
          bit_size = 63
          BinaryAccessor.read(0,  bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(65, bit_size, :UINT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read 63-bit signed integers" do
          expected = [0x8081828384858687 >> 1, 0x00090A0B0C0D0E0F]
          bit_size = 63
          expected.each_with_index { |value, index| expected[index] = value - 2**bit_size if value >= 2**(bit_size - 1) }
          BinaryAccessor.read(0,  bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(65, bit_size, :INT, @data, :BIG_ENDIAN).should eql(expected[1])
        end

        it "should read aligned 64-bit unsigned integers" do
          expected_array = [0x8081828384858687, 0x00090A0B0C0D0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 64) do |bit_offset|
            BinaryAccessor.read(bit_offset, 64, :UINT, @data, :BIG_ENDIAN).should eql(expected_array[index])
            index += 1
          end
        end

        it "should read aligned 64-bit signed integers" do
          expected_array = [0x8081828384858687, 0x00090A0B0C0D0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 64) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**64 if expected >= 2**63
            BinaryAccessor.read(bit_offset, 64, :INT, @data, :BIG_ENDIAN).should eql(expected)
            index += 1
          end
        end

        it "should read aligned 64-bit floats" do
          expected_array = [-3.116851e-306, 1.257060e-308]
          BinaryAccessor.read(0,  64, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-306).of(expected_array[0])
          BinaryAccessor.read(64, 64, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-308).of(expected_array[1])
        end

        it "should complain about unaligned floats" do
          lambda { BinaryAccessor.read(17, 32, :FLOAT, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "bit_offset 17 is not byte aligned for data_type FLOAT")
        end

        it "should complain about mis-sized floats" do
          lambda { BinaryAccessor.read(0, 33, :FLOAT, @data, :BIG_ENDIAN) }.should raise_error(ArgumentError, "bit_size is 33 but must be 32 or 64 for data_type FLOAT")
        end

      end # given big endian data

      describe "given little endian data" do

        it "should complain about ill-defined little endian bitfields" do
          lambda { BinaryAccessor.read(3, 7, :UINT, @data, :LITTLE_ENDIAN) }.should raise_error(ArgumentError, "LITTLE_ENDIAN bitfield with bit_offset 3 and bit_size 7 is invalid")
        end

        it "should read 1-bit unsigned integers" do
          expected = [0x1, 0x0]
          bit_size = 1
          BinaryAccessor.read(8, bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(9, bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read 1-bit signed integers" do
          expected = [0x1, 0x0]
          bit_size = 1
          BinaryAccessor.read(8, bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(9, bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read 7-bit unsigned integers" do
          expected = [0x40, 0x60]
          bit_size = 7
          BinaryAccessor.read(8, bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(15, bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read 7-bit signed integers" do
          expected = [0x40, 0x60]
          bit_size = 7
          expected.each_with_index { |value, index| expected[index] = value - 2**bit_size if value >= 2**(bit_size - 1) }
          BinaryAccessor.read(8, bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(15, bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read 13-bit unsigned integers" do
          expected = [0x038281 >> 5, 0x0180 >> 2]
          bit_size = 13
          BinaryAccessor.read(30, bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(9,  bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read 13-bit signed integers" do
          expected = [0x038281 >> 5, 0x0180 >> 2]
          bit_size = 13
          expected.each_with_index { |value, index| expected[index] = value - 2**bit_size if value >= 2**(bit_size - 1) }
          BinaryAccessor.read(30, bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(9,  bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read aligned 16-bit unsigned integers" do
          expected_array = [0x8180, 0x8382, 0x8584, 0x8786, 0x0900, 0x0B0A, 0x0D0C, 0x0F0E]
          index = 0
          0.step((@data.length - 1) * 8, 16) do |bit_offset|
            BinaryAccessor.read(bit_offset, 16, :UINT, @data, :LITTLE_ENDIAN).should eql(expected_array[index])
            index += 1
          end
        end

        it "should read aligned 16-bit signed integers" do
          expected_array = [0x8180, 0x8382, 0x8584, 0x8786, 0x0900, 0x0B0A, 0x0D0C, 0x0F0E]
          index = 0
          0.step((@data.length - 1) * 8, 16) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**16 if expected >= 2**15
            BinaryAccessor.read(bit_offset, 16, :INT, @data, :LITTLE_ENDIAN).should eql(expected)
            index += 1
          end
        end

        it "should read aligned 32-bit unsigned integers" do
          expected_array = [0x83828180, 0x87868584, 0x0B0A0900, 0x0F0E0D0C]
          index = 0
          0.step((@data.length - 1) * 8, 32) do |bit_offset|
            BinaryAccessor.read(bit_offset, 32, :UINT, @data, :LITTLE_ENDIAN).should eql(expected_array[index])
            index += 1
          end
        end

        it "should read aligned 32-bit signed integers" do
          expected_array = [0x83828180, 0x87868584, 0x0B0A0900, 0x0F0E0D0C]
          index = 0
          0.step((@data.length - 1) * 8, 32) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**32 if expected >= 2**31
            BinaryAccessor.read(bit_offset, 32, :INT, @data, :LITTLE_ENDIAN).should eql(expected)
            index += 1
          end
        end

        it "should read aligned 32-bit floats" do
          expected_array = [-7.670445e-037, -2.024055e-034, 2.658460e-032, 7.003653e-030]
          BinaryAccessor.read(0,  32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-037).of(expected_array[0])
          BinaryAccessor.read(32, 32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-034).of(expected_array[1])
          BinaryAccessor.read(64, 32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-032).of(expected_array[2])
          BinaryAccessor.read(96, 32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-030).of(expected_array[3])
        end

        it "should read 37-bit unsigned integers" do
          expected = [0x8584838281 >> 3, 0x0F0E0D0C0B]
          bit_size = 37
          BinaryAccessor.read(40,  bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(123, bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read 37-bit signed integers" do
          expected = [0x8584838281 >> 3, 0x0F0E0D0C0B]
          bit_size = 37
          expected.each_with_index { |value, index| expected[index] = value - 2**bit_size if value >= 2**(bit_size - 1) }
          BinaryAccessor.read(40,  bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(123, bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read 63-bit unsigned integers" do
          expected = [0x0F0E0D0C0B0A0900 >> 1, 0x0786858483828180]
          bit_size = 63
          BinaryAccessor.read(120,  bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(57, bit_size, :UINT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read 63-bit signed integers" do
          expected = [0x0F0E0D0C0B0A0900 >> 1, 0x0786858483828180]
          bit_size = 63
          expected.each_with_index { |value, index| expected[index] = value - 2**bit_size if value >= 2**(bit_size - 1) }
          BinaryAccessor.read(120,  bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[0])
          BinaryAccessor.read(57,   bit_size, :INT, @data, :LITTLE_ENDIAN).should eql(expected[1])
        end

        it "should read aligned 64-bit unsigned integers" do
          expected_array = [0x8786858483828180, 0x0F0E0D0C0B0A0900]
          index = 0
          0.step((@data.length - 1) * 8, 64) do |bit_offset|
            BinaryAccessor.read(bit_offset, 64, :UINT, @data, :LITTLE_ENDIAN).should eql(expected_array[index])
            index += 1
          end
        end

        it "should read aligned 64-bit signed integers" do
          expected_array = [0x8786858483828180, 0x0F0E0D0C0B0A0900]
          index = 0
          0.step((@data.length - 1) * 8, 64) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**64 if expected >= 2**63
            BinaryAccessor.read(bit_offset, 64, :INT, @data, :LITTLE_ENDIAN).should eql(expected)
            index += 1
          end
        end

        it "should read aligned 64-bit floats" do
          expected_array = [-2.081577e-272, 3.691916e-236]
          BinaryAccessor.read(0,  64, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-272).of(expected_array[0])
          BinaryAccessor.read(64, 64, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-236).of(expected_array[1])
        end

        it "should complain about unaligned floats" do
          lambda { BinaryAccessor.read(1, 32, :FLOAT, @data, :LITTLE_ENDIAN) }.should raise_error(ArgumentError, "bit_offset 1 is not byte aligned for data_type FLOAT")
        end

        it "should complain about mis-sized floats" do
          lambda { BinaryAccessor.read(0, 65, :FLOAT, @data, :LITTLE_ENDIAN) }.should raise_error(ArgumentError, "bit_size is 65 but must be 32 or 64 for data_type FLOAT")
        end

      end # little endian
    end # describe 'read'

    describe "read_array" do

      before(:each) do
        @data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
      end

      it "should complain with unknown data_type" do
          expect { BinaryAccessor.read_array(0, 8, :BLAH, 0, @data, :LITTLE_ENDIAN) }.to raise_error(ArgumentError, "data_type BLAH is not recognized")
      end

      describe "given little endian data" do

        it "should complain about negative bit sizes" do
          expect { BinaryAccessor.read_array(0, -8, :UINT, @data.length*8, @data, :LITTLE_ENDIAN) }.to raise_error(ArgumentError, "bit_size -8 must be positive for arrays")
        end

        context "when positive or zero bit_offset" do
          it "should read the given array_size amount of items" do
            data = @data.unpack('C*')
            BinaryAccessor.read_array(0, 8, :UINT, 32, @data, :LITTLE_ENDIAN).should eql(data[0..3])
          end

          it "should read the given array_size amount of items" do
            data = @data.unpack('C*')
            BinaryAccessor.read_array(32, 8, :UINT, 32, @data, :LITTLE_ENDIAN).should eql(data[4..7])
          end

          it "should read the total buffer given array_size = buffer size" do
            data = @data.unpack('c*')

            BinaryAccessor.read_array(0, 8, :INT, @data.length*8, @data, :LITTLE_ENDIAN).should eql(data)
          end

          it "should complain with an array_size not a multiple of bit_size" do
            data = @data.unpack('C*')
            expect { BinaryAccessor.read_array(0, 8, :UINT, 10, @data, :LITTLE_ENDIAN) }.to raise_error(ArgumentError, "array_size 10 not a multiple of bit_size 8")
          end

          it "should read as many items as possible with a zero array_size" do
            data = @data.unpack('C*')
            BinaryAccessor.read_array(0, 8, :UINT, 0, @data, :LITTLE_ENDIAN).should eql(data)
          end

          it "should exclude the remaining bits if array_size is negative" do
            data = @data.unpack('C*')
            BinaryAccessor.read_array(0, 8, :UINT, -32, @data, :LITTLE_ENDIAN).should eql(data[0..-5])
          end

          it "should return an empty array if the offset equals the negative array size" do
            data = @data.unpack('C*')
            BinaryAccessor.read_array(@data.length*8-32, 8, :UINT, -32, @data, :LITTLE_ENDIAN).should eql([])
          end

          it "should complain if the offset is greater than the negative array size" do
            data = @data.unpack('C*')
            offset = @data.length * 8 - 16
            expect { BinaryAccessor.read_array(offset, 8, :UINT, -32, @data, :LITTLE_ENDIAN) }.to raise_error(ArgumentError, "16 byte buffer insufficient to read UINT at bit_offset #{offset} with bit_size 8")
          end
        end

        context "when negative bit_offset" do
          it "should read an array of aligned 8 bit unsigned integers" do
            data = @data.unpack('C*')
            BinaryAccessor.read_array(-32, 8, :UINT, 32, @data, :LITTLE_ENDIAN).should eql(data[-4..-1])
          end

          it "should read an array if the negative offset is the size of the array" do
            data = @data.unpack('C*')
            BinaryAccessor.read_array(-(@data.length*8), 8, :UINT, @data.length*8, @data, :LITTLE_ENDIAN).should eql(data)
          end

          it "should complain if the offset is larger than the buffer" do
            expect { BinaryAccessor.read_array(-(@data.length*8+1), 8, :UINT, @data.length*8, @data, :LITTLE_ENDIAN) }.to raise_error(ArgumentError, "#{@data.length} byte buffer insufficient to read #{:UINT} at bit_offset -#{@data.length*8+1} with bit_size 8")
          end

          it "should complain with zero array_size" do
            expect { BinaryAccessor.read_array(-32, 8, :UINT, 0, @data, :LITTLE_ENDIAN) }.to raise_error(ArgumentError, "negative or zero array_size (0) cannot be given with negative bit_offset (-32)")
          end

          it "should complain with negative array_size" do
            expect { BinaryAccessor.read_array(-32, 8, :UINT, -8, @data, :LITTLE_ENDIAN) }.to raise_error(ArgumentError, "negative or zero array_size (-8) cannot be given with negative bit_offset (-32)")
          end
        end

        it "should complain about accessing data from a buffer which is too small" do
          expect { BinaryAccessor.read_array(0, 256, :STRING, 256, @data, :LITTLE_ENDIAN) }.to raise_error(ArgumentError, "16 byte buffer insufficient to read STRING at bit_offset 0 with bit_size 256")
        end

        it "should return an empty array when passed a zero length buffer" do
          BinaryAccessor.read_array(0, 8, :UINT, 32, "", :LITTLE_ENDIAN).should eql([])
        end

        it "should complain about unaligned strings" do
          lambda { BinaryAccessor.read_array(1, 32, :STRING, 32, @data, :LITTLE_ENDIAN) }.should raise_error(ArgumentError, "bit_offset 1 is not byte aligned for data_type STRING")
        end

        it "should read a single STRING item" do
          BinaryAccessor.read_array(0, 128, :STRING, 0, @data, :LITTLE_ENDIAN).should eql([@data[0..7]])
        end

        it "should read a single BLOCK item" do
          BinaryAccessor.read_array(0, 128, :BLOCK, 0, @data, :LITTLE_ENDIAN).should eql([@data])
        end

        it "should read BLOCK items" do
          data = BinaryAccessor.read_array(0, 8, :BLOCK, 0, @data, :LITTLE_ENDIAN)
          data.each_with_index {|val, i| val.should eql(@data[i]) }
        end

        it "should read 1-bit integers" do
          expected = [0x1, 0x0, 0x0, 0x0]
          BinaryAccessor.read_array(0, 1, :INT, 4, @data, :LITTLE_ENDIAN).should eql(expected)
          BinaryAccessor.read_array(0, 1, :INT, 2, @data, :LITTLE_ENDIAN).should eql(expected[0..1])
        end

        it "should complain about little endian bit-fields greater than 1-bit" do
          expect { BinaryAccessor.read_array(8, 7, :UINT, 21, @data, :LITTLE_ENDIAN) }.to raise_error(ArgumentError, "read_array does not support little endian bit fields with bit_size greater than 1-bit")
        end

        it "should read 16 bit UINT items" do
          data = [0x8180, 0x8382, 0x8584, 0x8786, 0x0900, 0x0B0A, 0x0D0C, 0x0F0E]
          BinaryAccessor.read_array(0, 16, :UINT, 0, @data, :LITTLE_ENDIAN).should eql(data)
        end

        it "should read 16 bit INT items" do
          data = [0x8180, 0x8382, 0x8584, 0x8786, 0x0900, 0x0B0A, 0x0D0C, 0x0F0E]
          data.map! {|x| (x & ~(1 << 15)) - (x & (1 << 15)) } # convert to negative
          BinaryAccessor.read_array(0, 16, :INT, 0, @data, :LITTLE_ENDIAN).should eql(data)
        end

        it "should read 32 bit UINT items" do
          data = [0x83828180, 0x87868584, 0x0B0A0900, 0x0F0E0D0C]
          BinaryAccessor.read_array(0, 32, :UINT, 0, @data, :LITTLE_ENDIAN).should eql(data)
        end

        it "should read 32 bit INT items" do
          data = [0x83828180, 0x87868584, 0x0B0A0900, 0x0F0E0D0C]
          data.map! {|x| (x & ~(1 << 31)) - (x & (1 << 31)) } # convert to negative
          BinaryAccessor.read_array(0, 32, :INT, 0, @data, :LITTLE_ENDIAN).should eql(data)
        end

        it "should read 64 bit UINT items" do
          data = [0x8786858483828180, 0x0F0E0D0C0B0A0900]
          BinaryAccessor.read_array(0, 64, :UINT, 0, @data, :LITTLE_ENDIAN).should eql(data)
        end

        it "should read 64 bit INT items" do
          data = [0x8786858483828180, 0x0F0E0D0C0B0A0900]
          data.map! {|x| (x & ~(1 << 63)) - (x & (1 << 63)) } # convert to negative
          BinaryAccessor.read_array(0, 64, :INT, 0, @data, :LITTLE_ENDIAN).should eql(data)
        end

        it "should read aligned 32-bit floats" do
          expected_array = [-7.670445e-037, -2.024055e-034, 2.658460e-032, 7.003653e-030]
          actual = BinaryAccessor.read_array(0, 32, :FLOAT, 0, @data, :LITTLE_ENDIAN)
          actual.each_with_index do |val, index|
            val.should be_within(1.0e-030).of(expected_array[index])
          end
        end

        it "should read aligned 64-bit floats" do
          expected_array = [-2.081577e-272, 3.691916e-236]
          actual = BinaryAccessor.read_array(0, 64, :FLOAT, 0, @data, :LITTLE_ENDIAN)
          actual.each_with_index do |val, index|
            val.should be_within(1.0e-236).of(expected_array[index])
          end
        end

        it "should complain about unaligned floats" do
          lambda { BinaryAccessor.read_array(1, 32, :FLOAT, 32, @data, :LITTLE_ENDIAN) }.should raise_error(ArgumentError, "bit_offset 1 is not byte aligned for data_type FLOAT")
        end

        it "should complain about mis-sized floats" do
          lambda { BinaryAccessor.read_array(0, 65, :FLOAT, 65, @data, :LITTLE_ENDIAN) }.should raise_error(ArgumentError, "bit_size is 65 but must be 32 or 64 for data_type FLOAT")
        end
      end # given little endian data

      describe "given big endian data" do

        it "should read 7-bit unsigned integers" do
          expected = [0x40, 0x60, 0x50]
          bit_size = 7
          BinaryAccessor.read_array(8, bit_size, :UINT, 21, @data, :BIG_ENDIAN).should eql(expected)
        end

        it "should read 16 bit UINT items" do
          data = [0x8081, 0x8283, 0x8485, 0x8687, 0x0009, 0x0A0B, 0x0C0D, 0x0E0F]
          BinaryAccessor.read_array(0, 16, :UINT, 0, @data, :BIG_ENDIAN).should eql(data)
        end

        it "should read 16 bit INT items" do
          data = [0x8081, 0x8283, 0x8485, 0x8687, 0x0009, 0x0A0B, 0x0C0D, 0x0E0F]
          data.map! {|x| (x & ~(1 << 15)) - (x & (1 << 15)) } # convert to negative
          BinaryAccessor.read_array(0, 16, :INT, 0, @data, :BIG_ENDIAN).should eql(data)
        end

        it "should read 32 bit UINT items" do
          data = [0x80818283, 0x84858687, 0x00090A0B, 0x0C0D0E0F]
          BinaryAccessor.read_array(0, 32, :UINT, 0, @data, :BIG_ENDIAN).should eql(data)
        end

        it "should read 32 bit INT items" do
          data = [0x80818283, 0x84858687, 0x00090A0B, 0x0C0D0E0F]
          data.map! {|x| (x & ~(1 << 31)) - (x & (1 << 31)) } # convert to negative
          BinaryAccessor.read_array(0, 32, :INT, 0, @data, :BIG_ENDIAN).should eql(data)
        end

        it "should read 64 bit UINT items" do
          data = [0x8081828384858687, 0x00090A0B0C0D0E0F]
          BinaryAccessor.read_array(0, 64, :UINT, 0, @data, :BIG_ENDIAN).should eql(data)
        end

        it "should read 64 bit INT items" do
          data = [0x8081828384858687, 0x00090A0B0C0D0E0F]
          data.map! {|x| (x & ~(1 << 63)) - (x & (1 << 63)) } # convert to negative
          BinaryAccessor.read_array(0, 64, :INT, 0, @data, :BIG_ENDIAN).should eql(data)
        end

        it "should read aligned 32-bit floats" do
          expected_array = [-1.189360e-038, -3.139169e-036, 8.301067e-040, 1.086646e-031]
          actual = BinaryAccessor.read_array(0, 32, :FLOAT, 0, @data, :BIG_ENDIAN)
          actual.each_with_index do |val, index|
            val.should be_within(1.0e-030).of(expected_array[index])
          end
        end

        it "should read aligned 64-bit floats" do
          expected_array = [-3.116851e-306, 1.257060e-308]
          actual = BinaryAccessor.read_array(0, 64, :FLOAT, 0, @data, :BIG_ENDIAN)
          actual.each_with_index do |val, index|
            val.should be_within(1.0e-236).of(expected_array[index])
          end
        end
      end # given big endian data
    end # describe "read_array"

    describe "write" do

      before(:each) do
        @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        @baseline_data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
      end

      it "should complain about unrecognized data types" do
        lambda { BinaryAccessor.write(0, 0, 32, :BLOB, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "data_type BLOB is not recognized")
      end

      it "should complain about bit_offsets before the beginning of the buffer" do
        lambda { BinaryAccessor.write('', -((@data.length * 8) + 8), 32, :STRING, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "#{@data.length} byte buffer insufficient to write STRING at bit_offset #{-((@data.length * 8) + 8)} with bit_size 32")
      end

      it "should complain about a negative bit_offset and zero bit_size" do
        lambda { BinaryAccessor.write('', -8, 0, :STRING, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "negative or zero bit_sizes (0) cannot be given with negative bit_offsets (-8)")
      end

      it "should complain about a negative bit_offset and negative bit_size" do
        lambda { BinaryAccessor.write('', -8, -8, :STRING, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "negative or zero bit_sizes (-8) cannot be given with negative bit_offsets (-8)")
      end

      it "should complain about negative or zero bit_sizes with data_types other than STRING and BLOCK" do
        lambda { BinaryAccessor.write(0, 0, -8, :INT, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_size -8 must be positive for data types other than :STRING and :BLOCK")
        lambda { BinaryAccessor.write(0, 0, -8, :UINT, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_size -8 must be positive for data types other than :STRING and :BLOCK")
        lambda { BinaryAccessor.write(0, 0, -8, :FLOAT, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_size -8 must be positive for data types other than :STRING and :BLOCK")
      end

      it "should write aligned strings" do
        0.step((@data.length - 1) * 8, 8) do |bit_offset|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          @expected_data = @baseline_data.clone
          first_byte_index = bit_offset / 8
          if first_byte_index > 0
            @expected_data[0..(first_byte_index - 1)] = "\x00" * first_byte_index
          end
          BinaryAccessor.write(@baseline_data[first_byte_index..-1], bit_offset, (@data.length * 8) - bit_offset, :STRING, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@expected_data)
        end
      end

      it "should write variable length strings with a zero and negative bit_size" do
        0.step(-(@baseline_data.length * 8), -8) do |bit_size|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          @expected_data = @baseline_data.clone + ("\x00" * -(bit_size / 8))
          BinaryAccessor.write(@baseline_data, 0, bit_size, :STRING, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@expected_data)
        end
      end

      it "should write strings with negative bit_offsets" do
        BinaryAccessor.write(@baseline_data[14..15], -16, 16, :STRING, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql(("\x00" * 14) + @baseline_data[14..15])
      end

      it "should complain about unaligned strings" do
        lambda { BinaryAccessor.write('', 1, 32, :STRING, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_offset 1 is not byte aligned for data_type STRING")
      end

      it "should write aligned blocks" do
        0.step((@data.length - 1) * 8, 8) do |bit_offset|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          @expected_data = @baseline_data.clone
          first_byte_index = bit_offset / 8
          if first_byte_index > 0
            @expected_data[0..(first_byte_index - 1)] = "\x00" * first_byte_index
          end
          BinaryAccessor.write(@baseline_data[first_byte_index..-1], bit_offset, (@data.length * 8) - bit_offset, :BLOCK, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@expected_data)
        end
      end

      it "should write variable length blocks with a zero and negative bit_size" do
        0.step(-(@data.length * 8), -8) do |bit_size|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          @expected_data = @baseline_data.clone + ("\x00" * -(bit_size / 8))
          BinaryAccessor.write(@baseline_data, 0, bit_size, :BLOCK, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@expected_data)
        end
      end

      it "should write blocks with negative bit_offsets" do
        BinaryAccessor.write(@baseline_data[0..1], -16, 16, :BLOCK, @data, :BIG_ENDIAN, :ERROR)
        @data[-2..-1].should eql(@baseline_data[0..1])
      end

      it "should write a blank string with zero bit size" do
        BinaryAccessor.write('', 0, 0, :STRING, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql('')
      end

      it "should write a blank block with zero bit size" do
        BinaryAccessor.write('', 0, 0, :BLOCK, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql('')
      end

      it "should write a shorter string with zero bit size" do
        BinaryAccessor.write("\x00\x00\x00\x00\x00\x00\x00\x00", 0, 0, :STRING, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x00\x00\x00\x00\x00\x00\x00\x00")
      end

      it "should write a shorter block with zero bit size" do
        BinaryAccessor.write("\x00\x00\x00\x00\x00\x00\x00\x00", 0, 0, :BLOCK, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x00\x00\x00\x00\x00\x00\x00\x00")
      end

      it "should write a shorter string and zero fill to the given bit size" do
        @data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
        BinaryAccessor.write("\x01\x02\x03\x04\x05\x06\x07\x08", 0, 128, :STRING, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x01\x02\x03\x04\x05\x06\x07\x08\x00\x00\x00\x00\x00\x00\x00\x00")
      end

      it "should write a shorter block and zero fill to the given bit size" do
        @data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
        BinaryAccessor.write("\x01\x02\x03\x04\x05\x06\x07\x08", 0, 128, :BLOCK, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x01\x02\x03\x04\x05\x06\x07\x08\x00\x00\x00\x00\x00\x00\x00\x00")
      end

      it "should complain about unaligned blocks" do
        lambda { BinaryAccessor.write(@baseline_data, 7, 16, :BLOCK, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_offset 7 is not byte aligned for data_type BLOCK")
      end

      it "should complain if write exceeds the size of the buffer" do
        lambda { BinaryAccessor.write(@baseline_data, 8, 800, :STRING, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "16 byte buffer insufficient to write STRING at bit_offset 8 with bit_size 800")
      end

      it "should write aligned 8-bit unsigned integers" do
        0.step((@data.length - 1) * 8, 8) do |bit_offset|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          byte_index = bit_offset / 8
          BinaryAccessor.write(@baseline_data.getbyte(byte_index), bit_offset, 8, :UINT, @data, :BIG_ENDIAN, :ERROR)
          @data[byte_index..byte_index].should eq(@baseline_data[byte_index..byte_index])
        end
      end

      it "should write aligned 8-bit signed integers" do
        0.step((@data.length - 1) * 8, 8) do |bit_offset|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          byte_index = bit_offset / 8
          value = @baseline_data.getbyte(byte_index)
          value = value - 256 if value >= 128
          BinaryAccessor.write(value, bit_offset, 8, :INT, @data, :BIG_ENDIAN, :ERROR)
          @data[byte_index..byte_index].should eql(@baseline_data[byte_index..byte_index])
        end
      end

      describe "given big endian data" do

        it "should write 1-bit unsigned integers" do
          BinaryAccessor.write(0x1, 8, 1, :UINT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(0x0, 9, 1, :UINT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(0x1, 10, 1, :UINT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\xA0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 1-bit signed integers" do
          BinaryAccessor.write(0x1, 8, 1, :INT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(0x0, 9, 1, :INT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(0x1, 10, 1, :INT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\xA0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 7-bit unsigned integers" do
          BinaryAccessor.write(0x40, 8, 7, :UINT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          BinaryAccessor.write(0x20, 3, 7, :UINT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 7-bit signed integers" do
          BinaryAccessor.write(-64, 8, 7, :INT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          BinaryAccessor.write(32, 3, 7, :INT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 13-bit unsigned integers" do
          BinaryAccessor.write(0x1C24, 30, 13, :UINT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\x00\x00\x03\x84\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          BinaryAccessor.write(0x0020, 1,  13, :UINT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 13-bit signed integers" do
          BinaryAccessor.write(-988, 30, 13, :INT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\x00\x00\x03\x84\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          BinaryAccessor.write(32, 1,  13, :INT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write aligned 16-bit unsigned integers" do
          expected_array = [0x8081, 0x8283, 0x8485, 0x8687, 0x0009, 0x0A0B, 0x0C0D, 0x0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 16) do |bit_offset|
            BinaryAccessor.write(expected_array[index], bit_offset, 16, :UINT, @data, :BIG_ENDIAN, :ERROR)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 16-bit signed integers" do
          expected_array = [0x8081, 0x8283, 0x8485, 0x8687, 0x0009, 0x0A0B, 0x0C0D, 0x0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 16) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**16 if expected >= 2**15
            BinaryAccessor.write(expected, bit_offset, 16, :INT, @data, :BIG_ENDIAN, :ERROR)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit unsigned integers" do
          expected_array = [0x80818283, 0x84858687, 0x00090A0B, 0x0C0D0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 32) do |bit_offset|
            BinaryAccessor.write(expected_array[index], bit_offset, 32, :UINT, @data, :BIG_ENDIAN, :ERROR)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit signed integers" do
          expected_array = [0x80818283, 0x84858687, 0x00090A0B, 0x0C0D0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 32) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**32 if expected >= 2**31
            BinaryAccessor.write(expected_array[index], bit_offset, 32, :INT, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit floats" do
          expected_array = [-1.189360e-038, -3.139169e-036, 8.301067e-040, 1.086646e-031]
          BinaryAccessor.write(expected_array[0], 0,  32, :FLOAT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(expected_array[1], 32, 32, :FLOAT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(expected_array[2], 64, 32, :FLOAT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(expected_array[3], 96, 32, :FLOAT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.read(0,  32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-038).of(expected_array[0])
          BinaryAccessor.read(32, 32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-036).of(expected_array[1])
          BinaryAccessor.read(64, 32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-040).of(expected_array[2])
          BinaryAccessor.read(96, 32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-031).of(expected_array[3])
        end

        it "should write 37-bit unsigned integers" do
          BinaryAccessor.write(0x8182838485 >> 3, 8,  37, :UINT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(0x00090A0B0C, 67, 37, :UINT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\x81\x82\x83\x84\x80\x00\x00\x00\x09\x0A\x0B\x0C\x00\x00\x00")
        end

        it "should write 37-bit signed integers" do
          BinaryAccessor.write((0x8182838485 >> 3) - 2**37, 8,  37, :INT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(0x00090A0B0C, 67, 37, :INT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\x81\x82\x83\x84\x80\x00\x00\x00\x09\x0A\x0B\x0C\x00\x00\x00")
        end

        it "should write 63-bit unsigned integers" do
          BinaryAccessor.write(0x8081828384858687 >> 1, 0,  63, :UINT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(0x00090A0B0C0D0E0F, 65, 63, :UINT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x80\x81\x82\x83\x84\x85\x86\x86\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F")
        end

        it "should write 63-bit signed integers" do
          BinaryAccessor.write((0x8081828384858687 >> 1) - 2**63, 0,  63, :INT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(0x00090A0B0C0D0E0F, 65, 63, :INT, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x80\x81\x82\x83\x84\x85\x86\x86\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F")
        end

        it "should write aligned 64-bit unsigned integers" do
          expected_array = [0x8081828384858687, 0x00090A0B0C0D0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 64) do |bit_offset|
            BinaryAccessor.write(expected_array[index], bit_offset, 64, :UINT, @data, :BIG_ENDIAN, :ERROR)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 64-bit signed integers" do
          expected_array = [0x8081828384858687, 0x00090A0B0C0D0E0F]
          index = 0
          0.step((@data.length - 1) * 8, 64) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**64 if expected >= 2**63
            BinaryAccessor.write(expected_array[index], bit_offset, 64, :INT, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 64-bit floats" do
          expected_array = [-3.116851e-306, 1.257060e-308]
          BinaryAccessor.write(expected_array[0], 0,  64, :FLOAT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.write(expected_array[1], 64, 64, :FLOAT, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.read(0,  64, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-306).of(expected_array[0])
          BinaryAccessor.read(64, 64, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-308).of(expected_array[1])
        end

        it "should complain about unaligned floats" do
          lambda { BinaryAccessor.write(0.0, 17, 32, :FLOAT, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_offset 17 is not byte aligned for data_type FLOAT")
        end

        it "should complain about mis-sized floats" do
          lambda { BinaryAccessor.write(0.0, 0, 33, :FLOAT, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_size is 33 but must be 32 or 64 for data_type FLOAT")
        end

      end # given big endian data

      describe "given little endian data" do

        it "should complain about ill-defined little endian bitfields" do
          lambda { BinaryAccessor.write(0x1, 3, 7, :UINT, @data, :LITTLE_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "LITTLE_ENDIAN bitfield with bit_offset 3 and bit_size 7 is invalid")
        end

        it "should write 1-bit unsigned integers" do
          BinaryAccessor.write(0x1, 8, 1, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(0x0, 9, 1, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(0x1, 10, 1, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\xA0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 1-bit signed integers" do
          BinaryAccessor.write(0x1, 8, 1, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(0x0, 9, 1, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(0x1, 10, 1, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\xA0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 7-bit unsigned integers" do
          BinaryAccessor.write(0x40, 8, 7, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          BinaryAccessor.write(0x7F, 11, 7, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\xC0\x1F\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 7-bit signed integers" do
          BinaryAccessor.write(-64, 8, 7, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          BinaryAccessor.write(32, 11, 7, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 13-bit unsigned integers" do
          BinaryAccessor.write(0x1C24, 30, 13, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\x80\x84\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          BinaryAccessor.write(0x0020, 9,  13, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 13-bit signed integers" do
          BinaryAccessor.write(-988, 30, 13, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\x80\x84\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          BinaryAccessor.write(32, 9,  13, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write aligned 16-bit unsigned integers" do
          expected_array = [0x8180, 0x8382, 0x8584, 0x8786, 0x0900, 0x0B0A, 0x0D0C, 0x0F0E]
          index = 0
          0.step((@data.length - 1) * 8, 16) do |bit_offset|
            BinaryAccessor.write(expected_array[index], bit_offset, 16, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 16-bit signed integers" do
          expected_array = [0x8180, 0x8382, 0x8584, 0x8786, 0x0900, 0x0B0A, 0x0D0C, 0x0F0E]
          index = 0
          0.step((@data.length - 1) * 8, 16) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**16 if expected >= 2**15
            BinaryAccessor.write(expected, bit_offset, 16, :INT, @data, :LITTLE_ENDIAN, :ERROR)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit unsigned integers" do
          expected_array = [0x83828180, 0x87868584, 0x0B0A0900, 0x0F0E0D0C]
          index = 0
          0.step((@data.length - 1) * 8, 32) do |bit_offset|
            BinaryAccessor.write(expected_array[index], bit_offset, 32, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit signed integers" do
          expected_array = [0x83828180, 0x87868584, 0x0B0A0900, 0x0F0E0D0C]
          index = 0
          0.step((@data.length - 1) * 8, 32) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**32 if expected >= 2**31
            BinaryAccessor.write(expected_array[index], bit_offset, 32, :INT, @data, :LITTLE_ENDIAN, :ERROR_ALLOW_HEX)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit floats" do
          expected_array = [-7.670445e-037, -2.024055e-034, 2.658460e-032, 7.003653e-030]
          BinaryAccessor.write(expected_array[0], 0,  32, :FLOAT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(expected_array[1], 32, 32, :FLOAT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(expected_array[2], 64, 32, :FLOAT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(expected_array[3], 96, 32, :FLOAT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.read(0,  32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-037).of(expected_array[0])
          BinaryAccessor.read(32, 32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-034).of(expected_array[1])
          BinaryAccessor.read(64, 32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-032).of(expected_array[2])
          BinaryAccessor.read(96, 32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-030).of(expected_array[3])
        end

        it "should write 37-bit unsigned integers" do
          BinaryAccessor.write(0x1584838281, 43,  37, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(0x0C0B0A0900 >> 3, 96, 37, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\x81\x82\x83\x84\x15\x00\x00\x00\x09\x0A\x0B\x0C\x00\x00\x00")
        end

        it "should write 37-bit signed integers" do
          BinaryAccessor.write(0x1584838281 - 2**37, 43,  37, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(0x0C0B0A0900 >> 3, 96, 37, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\x81\x82\x83\x84\x15\x00\x00\x00\x09\x0A\x0B\x0C\x00\x00\x00")
        end

        it "should write 63-bit unsigned integers" do
          BinaryAccessor.write(0x4786858483828180, 57,  63, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(0x0F0E0D0C0B0A0900 >> 1, 120, 63, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x80\x81\x82\x83\x84\x85\x86\x47\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F")
        end

        it "should write 63-bit signed integers" do
          BinaryAccessor.write(0x4786858483828180 - 2**63, 57,  63, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(0x0F0E0D0C0B0A0900 >> 1, 120, 63, :INT, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x80\x81\x82\x83\x84\x85\x86\x47\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F")
        end

        it "should write aligned 64-bit unsigned integers" do
          expected_array = [0x8786858483828180, 0x0F0E0D0C0B0A0900]
          index = 0
          0.step((@data.length - 1) * 8, 64) do |bit_offset|
            BinaryAccessor.write(expected_array[index], bit_offset, 64, :UINT, @data, :LITTLE_ENDIAN, :ERROR)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 64-bit signed integers" do
          expected_array = [0x8786858483828180, 0x0F0E0D0C0B0A0900]
          index = 0
          0.step((@data.length - 1) * 8, 64) do |bit_offset|
            expected = expected_array[index]
            expected = expected - 2**64 if expected >= 2**63
            BinaryAccessor.write(expected_array[index], bit_offset, 64, :INT, @data, :LITTLE_ENDIAN, :ERROR_ALLOW_HEX)
            index += 1
          end
          @data.should eql(@baseline_data)
        end

        it "should write aligned 64-bit floats" do
          expected_array = [-2.081577e-272, 3.691916e-236]
          BinaryAccessor.write(expected_array[0], 0,  64, :FLOAT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.write(expected_array[1], 64, 64, :FLOAT, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.read(0,  64, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-272).of(expected_array[0])
          BinaryAccessor.read(64, 64, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-236).of(expected_array[1])
        end

        it "should complain about unaligned floats" do
          lambda { BinaryAccessor.write(0.0, 1, 32, :FLOAT, @data, :LITTLE_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_offset 1 is not byte aligned for data_type FLOAT")
        end

        it "should complain about mis-sized floats" do
          lambda { BinaryAccessor.write(0.0, 0, 65, :FLOAT, @data, :LITTLE_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_size is 65 but must be 32 or 64 for data_type FLOAT")
        end

      end # given little endian data

      describe "should support overflow types" do
        before(:each) do
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        end

        it "should prevent overflow of STRING" do
          lambda { BinaryAccessor.write("abcde", 0, 32, :STRING, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of 5 bytes does not fit into 4 bytes for data_type STRING")
        end

        it "should prevent overflow of BLOCK" do
          lambda { BinaryAccessor.write("abcde", 0, 32, :BLOCK, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of 5 bytes does not fit into 4 bytes for data_type BLOCK")
        end

        it "should prevent overflow of 8-bit INT" do
          bit_size = 8; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -(value + 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 16-bit INT" do
          bit_size = 16; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -(value + 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 32-bit INT" do
          bit_size = 32; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -(value + 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 64-bit INT" do
          bit_size = 64; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -(value + 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 3-bit INT" do
          bit_size = 3; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -(value + 1)
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 8-bit UINT" do
          bit_size = 8; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -1
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 16-bit UINT" do
          bit_size = 16; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -1
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 32-bit UINT" do
          bit_size = 32; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -1
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 64-bit UINT" do
          bit_size = 64; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -1
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 3-bit UINT" do
          bit_size = 3; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
          value = -1
          lambda { BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should truncate STRING" do
          BinaryAccessor.write("abcde", 0, 32, :STRING, @data, :BIG_ENDIAN, :TRUNCATE)
          @data[0..4].should eql "abcd\x00"
        end

        it "should truncate BLOCK" do
          BinaryAccessor.write("abcde", 0, 32, :BLOCK, @data, :BIG_ENDIAN, :TRUNCATE)
          @data[0..4].should eql "abcd\x00"
        end

        it "should truncate 8-bit INT" do
          bit_size = 8; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 16-bit INT" do
          bit_size = 16; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 32-bit INT" do
          bit_size = 32; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 64-bit INT" do
          bit_size = 64; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 3-bit INT" do
          bit_size = 3; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 8-bit UINT" do
          bit_size = 8; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 16-bit UINT" do
          bit_size = 16; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 32-bit UINT" do
          bit_size = 32; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 64-bit UINT" do
          bit_size = 64; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 3-bit UINT" do
          bit_size = 3; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should saturate 8-bit INT" do
          bit_size = 8; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -(value + 1); saturated_value = value + 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 16-bit INT" do
          bit_size = 16; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -(value + 1); saturated_value = value + 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 32-bit INT" do
          bit_size = 32; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -(value + 1); saturated_value = value + 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 64-bit INT" do
          bit_size = 64; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -(value + 1); saturated_value = value + 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 3-bit INT" do
          bit_size = 3; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -(value + 1); saturated_value = value + 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 8-bit UINT" do
          bit_size = 8; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -1; saturated_value = 0
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 16-bit UINT" do
          bit_size = 16; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -1; saturated_value = 0
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 32-bit UINT" do
          bit_size = 32; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -1; saturated_value = 0
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 64-bit UINT" do
          bit_size = 64; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -1; saturated_value = 0
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 3-bit UINT" do
          bit_size = 3; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
          value = -1; saturated_value = 0
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should allow hex value entry of 8-bit INT" do
          bit_size = 8; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

        it "should allow hex value entry of 16-bit INT" do
          bit_size = 16; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

        it "should allow hex value entry of 32-bit INT" do
          bit_size = 32; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

        it "should allow hex value entry of 64-bit INT" do
          bit_size = 64; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

        it "should allow hex value entry of 3-bit INT" do
          bit_size = 3; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write(value, 0, bit_size, data_type, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

      end

    end # describe "write"

    describe "write_array" do
      before(:each) do
        @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        @data_array = []
        @data.length.times {|i| @data_array << @data[i] }
        @baseline_data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
        @baseline_data_array = []
        @baseline_data.length.times {|i| @baseline_data_array << @baseline_data[i] }
      end

      it "should complain about value other than Array" do
        lambda { BinaryAccessor.write_array("", 0, 32, :STRING, 0, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "values must be an Array type class is String")
      end

      it "should complain about unrecognized data types" do
        lambda { BinaryAccessor.write_array([0], 0, 32, :BLOB, 0, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "data_type BLOB is not recognized")
      end

      it "should complain about bit_offsets before the beginning of the buffer" do
        expect { BinaryAccessor.write_array([''], -((@data.length * 8) + 8), 32, :STRING, 0, @data, :BIG_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "#{@data.length} byte buffer insufficient to write STRING at bit_offset #{-((@data.length * 8) + 8)} with bit_size 32")
      end

      it "should write if a negative bit_offset is equal to length of buffer" do
        BinaryAccessor.write_array(@baseline_data_array, -(@data.length * 8), 8, :BLOCK, @baseline_data_array.length*8, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql @baseline_data
      end

      it "should complain about a negative or zero bit_size" do
        expect { BinaryAccessor.write_array([''], 0, 0, :STRING, 0, @data, :BIG_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "bit_size 0 must be positive for arrays")
        expect { BinaryAccessor.write_array([''], 0, -8, :STRING, 0, @data, :BIG_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "bit_size -8 must be positive for arrays")
      end

      it "should write aligned strings with fixed array_size" do
        data = @data.clone
        BinaryAccessor.write_array(@baseline_data_array, 0, 8, :STRING, @baseline_data_array.length*8, data, :BIG_ENDIAN, :ERROR)
        data.should eql(@baseline_data)
      end

      it "should write aligned strings with zero array_size" do
        BinaryAccessor.write_array(@baseline_data_array, 0, 8, :STRING, 0, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql(@baseline_data)
      end

      it "should write strings with negative bit_offsets" do
        BinaryAccessor.write_array(@baseline_data_array[14..15], -16, 8, :STRING, 16, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql(("\x00" * 14) + @baseline_data[14..15])
      end

      it "should complain about unaligned strings" do
        expect { BinaryAccessor.write_array([], 1, 32, :STRING, 32, @data, :BIG_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "bit_offset 1 is not byte aligned for data_type STRING")
      end

      it "should complain if pass more values than the given array_size can hold" do
        expect { BinaryAccessor.write_array(@baseline_data_array, 0, 8, :BLOCK, 32, @data, :BIG_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "too many values #{@baseline_data_array.length} for given array_size 32 and bit_size 8")
      end

      it "should write blocks with fixed array_size" do
        BinaryAccessor.write_array(@baseline_data_array, 0, 8, :BLOCK, @baseline_data_array.length*8, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql(@baseline_data)
      end

      it "should zero fill if array_size > number of values passed" do
        data = @baseline_data.clone
        BinaryAccessor.write_array(["\x01","\x02","\x03","\x04"], 0, 8, :BLOCK, 64, @baseline_data, :BIG_ENDIAN, :ERROR)
        @baseline_data.should eql("\x01\x02\x03\x04" + "\x00" * 4 + data[8..-1])
      end

      it "should write blocks with fixed array_size at non zero offset" do
        BinaryAccessor.write_array(@baseline_data_array[0..-5], 32, 8, :BLOCK, @baseline_data_array.length*8-32, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql(("\x00" * 4) + @baseline_data[0..-5])
      end

      it "should write blocks with zero array_size" do
        BinaryAccessor.write_array(@baseline_data_array, 0, 8, :BLOCK, 0, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql(@baseline_data)
      end

      it "should write blocks with negative bit_offsets" do
        BinaryAccessor.write_array(["\x80\x81","\x82\x83"], -32, 16, :BLOCK, 32, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql(("\x00" * 12) + @baseline_data[0..3])
      end

      it "should complain with an array_size not a multiple of bit_size" do
        data = @data.unpack('C*')
        expect { BinaryAccessor.write_array([1,2], 0, 8, :UINT, 10, @data, :BIG_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "array_size 10 not a multiple of bit_size 8")
      end

      it "should complain with an array_size not a multiple of bit_size" do
        data = @data.unpack('C*')
        expect { BinaryAccessor.write_array([1,2], 0, 8, :UINT, -10, @data, :BIG_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "array_size -10 not a multiple of bit_size 8")
      end

      it "should exclude the remaining bits if array_size is negative" do
        data = @data.clone
        BinaryAccessor.write_array(@baseline_data_array[0..-5], 0, 8, :BLOCK, -32, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql(@baseline_data[0..-5] + data[-4..-1])
      end

      it "should not write if the offset equals the negative array size" do
        data = @data.clone
        BinaryAccessor.write_array([], @data.length*8-32, 8, :BLOCK, -32, @data, :LITTLE_ENDIAN, :ERROR)
        @data.should eql(data)
      end

      it "should expand the buffer to handle negative array size" do
        @data = "\x00\x01\x02\x00\x03"
        BinaryAccessor.write_array([1,2,3,4], 0, 32, :UINT, -8, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x00\x00\x00\x01\x00\x00\x00\x02\x00\x00\x00\x03\x00\x00\x00\x04\x03")
      end

      it "should shrink the buffer when handling negative array size" do
        # Start with one array item
        @data = "\x00\x01\x02\x00\x03"
        # Goto 4 array items array item
        BinaryAccessor.write_array([1,2,3,4], 0, 32, :UINT, -8, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x00\x00\x00\x01\x00\x00\x00\x02\x00\x00\x00\x03\x00\x00\x00\x04\x03")
        # Goto 2 array items
        BinaryAccessor.write_array([1,2], 0, 32, :UINT, -8, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x00\x00\x00\x01\x00\x00\x00\x02\x03")
        # Goto 0 array items
        BinaryAccessor.write_array([], 0, 32, :UINT, -8, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x03")
        # Go back to 1 array items
        BinaryAccessor.write_array([1], 0, 32, :UINT, -8, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x00\x00\x00\x01\x03")
      end

      it "complain when passed a zero length buffer" do
        expect { BinaryAccessor.write_array([1,2,3], 0, 8, :UINT, 32, "", :LITTLE_ENDIAN, :ERROR) }.to raise_error(ArgumentError)
      end

      it "should expand the buffer if the offset is greater than the negative array size" do
        offset = @data.length * 8 - 16
        data = @data.clone
        BinaryAccessor.write_array([1,2], offset, 8, :UINT, -32, @data, :LITTLE_ENDIAN, :ERROR)
        @data.should eql(data[0..-3] + "\x01\x02" + data[-4..-1])
      end

      it "should complain with negative bit_offset and zero array_size" do
        expect { BinaryAccessor.write_array([1,2], -32, 8, :UINT, 0, @data, :LITTLE_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "negative or zero array_size (0) cannot be given with negative bit_offset (-32)")
      end

      it "should complain with negative array_size" do
        expect { BinaryAccessor.write_array([1,2], -32, 8, :UINT, -8, @data, :LITTLE_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "negative or zero array_size (-8) cannot be given with negative bit_offset (-32)")
      end

      it "should write a shorter string and zero fill to the given bit size" do
        @data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
        BinaryAccessor.write_array(["\x01\x02","\x01\x02","\x01\x02","\x01\x02"], 0, 32, :STRING, 128, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x01\x02\x00\x00\x01\x02\x00\x00\x01\x02\x00\x00\x01\x02\x00\x00")
      end

      it "should write a shorter string and zero fill to the given bit size" do
        @data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
        BinaryAccessor.write_array(["\x01\x02","\x01\x02","\x01\x02","\x01\x02"], 0, 32, :BLOCK, 128, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x01\x02\x00\x00\x01\x02\x00\x00\x01\x02\x00\x00\x01\x02\x00\x00")
      end

      it "should complain about unaligned blocks" do
        lambda { BinaryAccessor.write_array(@baseline_data_array[0..1], 7, 16, :BLOCK, 32, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_offset 7 is not byte aligned for data_type BLOCK")
      end

      it "should complain if write exceeds the size of the buffer" do
        lambda { BinaryAccessor.write_array([], 8, 800, :STRING, 800, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "16 byte buffer insufficient to write STRING at bit_offset 8 with bit_size 800")
      end

      it "should write aligned 8-bit unsigned integers" do
        data = @data.clone
        BinaryAccessor.write_array([0,1,2,3,4,5,255,255], 0, 8, :UINT, 0, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x00\x01\x02\x03\x04\x05\xFF\xFF")
      end

      it "should write aligned 8-bit signed integers" do
        data = @data.clone
        BinaryAccessor.write_array([0,1,2,3,4,5,-1,127], 0, 8, :INT, 0, @data, :BIG_ENDIAN, :ERROR)
        @data.should eql("\x00\x01\x02\x03\x04\x05\xFF\x7F")
      end

      it "should complain about unaligned strings" do
        expect { BinaryAccessor.write_array(['X'], 1, 32, :STRING, 32, @data, :BIG_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "bit_offset 1 is not byte aligned for data_type STRING")
      end

      it "should write STRING items" do
        data = @baseline_data.clone
        BinaryAccessor.write_array(['a'], 0, 64, :STRING, 0, @baseline_data, :BIG_ENDIAN, :ERROR)
        @baseline_data.should eql("a\x00\x00\x00\x00\x00\x00\x00")
      end

      it "should write BLOCK items" do
        BinaryAccessor.write_array(["\x01","\x02","\x03","\x04"], 0, 32, :BLOCK, 0, @baseline_data, :BIG_ENDIAN, :ERROR)
        @baseline_data.should eql("\x01\x00\x00\x00\x02\x00\x00\x00\x03\x00\x00\x00\x04\x00\x00\x00")
      end

      it "should write variable length arrays with a zero and negative array_size" do
        baseline_data_array_uint8 = []
        @baseline_data.length.times {|i| baseline_data_array_uint8 << @baseline_data[i].ord }
        0.step(-(@baseline_data.length * 8), -8) do |array_size|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          @expected_data = @baseline_data.clone + ("\x00" * -(array_size / 8))
          BinaryAccessor.write_array(baseline_data_array_uint8, 0, 8, :UINT, array_size, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@expected_data)
        end
      end

      it "should write variable length arrays or 32-bit UINTS with a zero and negative array_size" do
        baseline_data = "\x01\x01\x01\x01\x02\x02\x02\x02\x03\x03\x03\x03\x04\x04\x04\x04"
        data_array_uint32 = [0x01010101, 0x02020202, 0x03030303, 0x04040404]
        0.step(-(baseline_data.length * 8), -8) do |array_size|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          @expected_data = baseline_data.clone + ("\x00" * -(array_size / 8))
          BinaryAccessor.write_array(data_array_uint32, 0, 32, :UINT, array_size, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@expected_data)
        end
      end

      it "should write variable length arrays of 32-bit UINTS with a zero and negative array_size and non-zero bit offset" do
        baseline_data = "\x01\x01\x01\x01\x02\x02\x02\x02\x03\x03\x03\x03\x04\x04\x04\x04"
        data_array_uint32 = [0x01010101, 0x02020202, 0x03030303, 0x04040404]
        0.step(-(baseline_data.length * 8), -8) do |array_size|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          @expected_data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" + baseline_data.clone + ("\x00" * -(array_size / 8))
          BinaryAccessor.write_array(data_array_uint32, 128, 32, :UINT, array_size, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@expected_data)
        end
      end

      it "should write variable length arrays of 32-bit UINTS with a zero and negative array_size and non-zero bit offset and grow the buffer" do
        baseline_data = "\x01\x01\x01\x01\x02\x02\x02\x02\x03\x03\x03\x03\x04\x04\x04\x04"
        data_array_uint32 = [0x01010101, 0x02020202, 0x03030303, 0x04040404]
        0.step(-(baseline_data.length * 8), -8) do |array_size|
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
          @expected_data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" + baseline_data.clone + ("\x00" * -(array_size / 8))
          BinaryAccessor.write_array(data_array_uint32, 128, 32, :UINT, array_size, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@expected_data)
        end
      end

      describe "given big endian data" do

        it "should write 1-bit unsigned integers" do
          BinaryAccessor.write_array([1,0,1], 8, 1, :UINT, 3, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\xA0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 1-bit signed integers" do
          BinaryAccessor.write_array([1,0,1], 8, 1, :INT, 0, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\xA0")
        end

        it "should write 7-bit unsigned integers" do
          BinaryAccessor.write_array([0x40,0x60,0x50], 8, 7, :UINT, 21, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql("\x00\x81\x82\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write aligned 16-bit unsigned integers" do
          data = [0x8081, 0x8283, 0x8485, 0x8687, 0x0009, 0x0A0B, 0x0C0D, 0x0E0F]
          BinaryAccessor.write_array(data, 0, 16, :UINT, 0, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 16-bit signed integers" do
          data = [0x8081, 0x8283, 0x8485, 0x8687, 0x0009, 0x0A0B, 0x0C0D, 0x0E0F]
          data.map! {|x| (x & ~(1 << 15)) - (x & (1 << 15)) } # convert to negative
          BinaryAccessor.write_array(data, 0, 16, :INT, 0, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit unsigned integers" do
          data = [0x80818283, 0x84858687, 0x00090A0B, 0x0C0D0E0F]
          BinaryAccessor.write_array(data, 0, 32, :UINT, 0, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit signed integers" do
          data = [0x80818283, 0x84858687, 0x00090A0B, 0x0C0D0E0F]
          data.map! {|x| (x & ~(1 << 31)) - (x & (1 << 31)) } # convert to negative
          BinaryAccessor.write_array(data, 0, 32, :INT, 0, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit floats" do
          data = [-1.189360e-038, -3.139169e-036, 8.301067e-040, 1.086646e-031]
          BinaryAccessor.write_array(data, 0, 32, :FLOAT, 0, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.read(0,  32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-038).of(data[0])
          BinaryAccessor.read(32, 32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-036).of(data[1])
          BinaryAccessor.read(64, 32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-040).of(data[2])
          BinaryAccessor.read(96, 32, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-031).of(data[3])
        end

        it "should write aligned 64-bit unsigned integers" do
          data = [0x8081828384858687, 0x00090A0B0C0D0E0F]
          BinaryAccessor.write_array(data, 0, 64, :UINT, 0, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 64-bit signed integers" do
          data = [0x8081828384858687, 0x00090A0B0C0D0E0F]
          data.map! {|x| (x & ~(1 << 63)) - (x & (1 << 63)) } # convert to negative
          BinaryAccessor.write_array(data, 0, 64, :INT, 0, @data, :BIG_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 64-bit floats" do
          data = [-3.116851e-306, 1.257060e-308]
          BinaryAccessor.write_array(data, 0,  64, :FLOAT, 0, @data, :BIG_ENDIAN, :ERROR)
          BinaryAccessor.read(0,  64, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-306).of(data[0])
          BinaryAccessor.read(64, 64, :FLOAT, @data, :BIG_ENDIAN).should be_within(1.0e-308).of(data[1])
        end

        it "should complain about unaligned floats" do
          lambda { BinaryAccessor.write_array([0.0], 17, 32, :FLOAT, 32, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_offset 17 is not byte aligned for data_type FLOAT")
        end

        it "should complain about mis-sized floats" do
          lambda { BinaryAccessor.write_array([0.0], 0, 33, :FLOAT, 33, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_size is 33 but must be 32 or 64 for data_type FLOAT")
        end

      end # given big endian data

      describe "given little endian data" do

        it "should write 1-bit unsigned integers" do
          BinaryAccessor.write_array([1,0,1], 8, 1, :UINT, 3, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\xA0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        end

        it "should write 1-bit signed integers" do
          BinaryAccessor.write_array([1,0,1], 8, 1, :INT, 0, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql("\x00\xA0")
        end

        it "should complain about little endian bit-fields greater than 1-bit" do
          expect { BinaryAccessor.write_array([0x40,0x60,0x50], 8, 7, :UINT, 21, @data, :LITTLE_ENDIAN, :ERROR) }.to raise_error(ArgumentError, "write_array does not support little endian bit fields with bit_size greater than 1-bit")
        end

        it "should write aligned 16-bit unsigned integers" do
          data = [0x8180, 0x8382, 0x8584, 0x8786, 0x0900, 0x0B0A, 0x0D0C, 0x0F0E]
          BinaryAccessor.write_array(data, 0, 16, :UINT, 0, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 16-bit signed integers" do
          data = [0x8180, 0x8382, 0x8584, 0x8786, 0x0900, 0x0B0A, 0x0D0C, 0x0F0E]
          data.map! {|x| (x & ~(1 << 15)) - (x & (1 << 15)) } # convert to negative
          BinaryAccessor.write_array(data, 0, 16, :INT, 0, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit unsigned integers" do
          data = [0x83828180, 0x87868584, 0x0B0A0900, 0x0F0E0D0C]
          BinaryAccessor.write_array(data, 0, 32, :UINT, 0, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit signed integers" do
          data= [0x83828180, 0x87868584, 0x0B0A0900, 0x0F0E0D0C]
          data.map! {|x| (x & ~(1 << 31)) - (x & (1 << 31)) } # convert to negative
          BinaryAccessor.write_array(data, 0, 32, :INT, 0, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 32-bit floats" do
          data = [-7.670445e-037, -2.024055e-034, 2.658460e-032, 7.003653e-030]
          BinaryAccessor.write_array(data, 0, 32, :FLOAT, 0, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.read(0,  32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-037).of(data[0])
          BinaryAccessor.read(32, 32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-034).of(data[1])
          BinaryAccessor.read(64, 32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-032).of(data[2])
          BinaryAccessor.read(96, 32, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-030).of(data[3])
        end

        it "should write aligned 64-bit unsigned integers" do
          data = [0x8786858483828180, 0x0F0E0D0C0B0A0900]
          BinaryAccessor.write_array(data, 0, 64, :UINT, 0, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 64-bit signed integers" do
          data = [0x8786858483828180, 0x0F0E0D0C0B0A0900]
          data.map! {|x| (x & ~(1 << 63)) - (x & (1 << 63)) } # convert to negative
          BinaryAccessor.write_array(data, 0, 64, :INT, 0, @data, :LITTLE_ENDIAN, :ERROR)
          @data.should eql(@baseline_data)
        end

        it "should write aligned 64-bit floats" do
          data = [-2.081577e-272, 3.691916e-236]
          BinaryAccessor.write_array(data, 0, 64, :FLOAT, 0, @data, :LITTLE_ENDIAN, :ERROR)
          BinaryAccessor.read(0,  64, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-272).of(data[0])
          BinaryAccessor.read(64, 64, :FLOAT, @data, :LITTLE_ENDIAN).should be_within(1.0e-236).of(data[1])
        end

        it "should complain about unaligned floats" do
          lambda { BinaryAccessor.write_array([0.0], 1, 32, :FLOAT, 32, @data, :LITTLE_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_offset 1 is not byte aligned for data_type FLOAT")
        end

        it "should complain about mis-sized floats" do
          lambda { BinaryAccessor.write_array([0.0], 0, 65, :FLOAT, 65, @data, :LITTLE_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "bit_size is 65 but must be 32 or 64 for data_type FLOAT")
        end

      end # given little endian data

      describe "should support overflow types" do
        before(:each) do
          @data = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        end

        it "should prevent overflow of STRING" do
          lambda { BinaryAccessor.write_array(["abcde"], 0, 32, :STRING, 32, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of 5 bytes does not fit into 4 bytes for data_type STRING")
        end

        it "should prevent overflow of BLOCK" do
          lambda { BinaryAccessor.write_array(["abcde"], 0, 32, :BLOCK, 32, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of 5 bytes does not fit into 4 bytes for data_type BLOCK")
        end

        it "should prevent overflow of 8-bit INT" do
          bit_size = 8; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 16-bit INT" do
          bit_size = 16; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 32-bit INT" do
          bit_size = 32; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 64-bit INT" do
          bit_size = 64; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 3-bit INT" do
          bit_size = 3; data_type = :INT; value = 2 ** (bit_size - 1)
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 8-bit UINT" do
          bit_size = 8; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 16-bit UINT" do
          bit_size = 16; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 32-bit UINT" do
          bit_size = 32; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 64-bit UINT" do
          bit_size = 64; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should prevent overflow of 3-bit UINT" do
          bit_size = 3; data_type = :UINT; value = 2 ** bit_size
          lambda { BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR) }.should raise_error(ArgumentError, "value of #{value} invalid for #{bit_size}-bit #{data_type}")
        end

        it "should truncate STRING" do
          BinaryAccessor.write_array(["abcde"], 0, 32, :STRING, 32, @data, :BIG_ENDIAN, :TRUNCATE)
          @data[0..4].should eql "abcd\x00"
        end

        it "should truncate BLOCK" do
          BinaryAccessor.write_array(["abcde"], 0, 32, :BLOCK, 32, @data, :BIG_ENDIAN, :TRUNCATE)
          @data[0..4].should eql "abcd\x00"
        end

        it "should truncate 8-bit INT" do
          bit_size = 8; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 16-bit INT" do
          bit_size = 16; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 32-bit INT" do
          bit_size = 32; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 64-bit INT" do
          bit_size = 64; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 3-bit INT" do
          bit_size = 3; data_type = :INT; value = 2 ** (bit_size - 1); truncated_value = -value
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 8-bit UINT" do
          bit_size = 8; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 16-bit UINT" do
          bit_size = 16; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 32-bit UINT" do
          bit_size = 32; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 64-bit UINT" do
          bit_size = 64; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should truncate 3-bit UINT" do
          bit_size = 3; data_type = :UINT; value = 2 ** bit_size + 1; truncated_value = 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :TRUNCATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql truncated_value
        end

        it "should saturate 8-bit INT" do
          bit_size = 8; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 16-bit INT" do
          bit_size = 16; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 32-bit INT" do
          bit_size = 32; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 64-bit INT" do
          bit_size = 64; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 3-bit INT" do
          bit_size = 3; data_type = :INT; value = 2 ** (bit_size - 1); saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 8-bit UINT" do
          bit_size = 8; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 16-bit UINT" do
          bit_size = 16; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 32-bit UINT" do
          bit_size = 32; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 64-bit UINT" do
          bit_size = 64; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should saturate 3-bit UINT" do
          bit_size = 3; data_type = :UINT; value = 2 ** bit_size; saturated_value = value - 1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :SATURATE)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql saturated_value
        end

        it "should allow hex value entry of 8-bit INT" do
          bit_size = 8; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

        it "should allow hex value entry of 16-bit INT" do
          bit_size = 16; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

        it "should allow hex value entry of 32-bit INT" do
          bit_size = 32; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

        it "should allow hex value entry of 64-bit INT" do
          bit_size = 64; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

        it "should allow hex value entry of 3-bit INT" do
          bit_size = 3; data_type = :INT; value = 2 ** bit_size - 1; allowed_value = -1
          BinaryAccessor.write_array([value], 0, bit_size, data_type, bit_size, @data, :BIG_ENDIAN, :ERROR_ALLOW_HEX)
          BinaryAccessor.read(0, bit_size, data_type, @data, :BIG_ENDIAN).should eql allowed_value
        end

      end

    end # describe "write_array"

  end # describe BinaryAccessor

end # module Cosmos
