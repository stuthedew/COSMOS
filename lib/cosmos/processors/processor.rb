# encoding: ascii-8bit

# Copyright � 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  class Processor

    # @return [Symbol] The value type for the processor
    attr_reader :value_type

    # @return [String] The processor name
    attr_reader :name

    # @return [Hash] The results of the most recent execution of the processor
    attr_accessor :results

    # Create a new Processor
    # @param value_type [Symbol or String] the value type to process
    def initialize(value_type = :CONVERTED)
      @name = self.class.to_s.upcase
      value_type = value_type.to_s.upcase.intern
      @value_type = value_type
      raise ArgumentError, "value_type must be RAW, CONVERTED, FORMATTED, or WITH_UNITS. Is #{@value_type}" unless Packet::VALUE_TYPES.include?(@value_type)
      @results = {}
    end

    def name=(name)
      @name = name.to_s.upcase
    end

    # Perform processing on the packet.
    #
    # @param packet [Packet] The packet which contains the value. This can
    #   be useful to reach into the packet and use other values in the
    #   conversion.
    # @param buffer [String] The packet buffer
    # @return The processed result
    def call(packet, buffer)
      raise "call method must be defined by subclass"
    end

    # @return [String] The processor class
    def to_s
      self.class.to_s.split('::')[-1]
    end

    # Reset any state
    def reset
      # By default do nothing
    end

    # Make a light weight clone of this processor. This only creates a new hash of results
    #
    # @return [Processor] A copy of the processor with a new hash of results
    def clone
      processor = super()
      processor.results = processor.results.clone
      processor
    end
    alias dup clone

  end # class Processor

end # module Cosmos
