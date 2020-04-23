# frozen_string_literal: true

module Datadog
  class Statsd
    class MessageBuffer
      PAYLOAD_SIZE_TOLERANCE = 0.05

      def initialize(connection,
        max_buffer_payload_size:,
        max_buffer_pool_size:,
        buffer_overflowing_stategy: :drop
      )
        @connection = connection
        @max_buffer_payload_size = max_buffer_payload_size
        @max_buffer_pool_size = max_buffer_pool_size
        @buffer_overflowing_stategy = buffer_overflowing_stategy

        @buffer = String.new
        @message_count = 0

        @depth = 0
      end

      def add(message)
        message_size = message.bytesize

        return nil unless ensure_sendable!(message_size)

        flush if should_flush?(message_size)

        buffer << "\n" unless buffer.empty?
        buffer << message

        @message_count += 1

        flush if preemptive_flush?

        true
      end

      def flush
        return if buffer.empty?

        connection.write(buffer)

        buffer.clear
        @message_count = 0
      end

      private
      attr :max_buffer_payload_size
      attr :max_buffer_pool_size

      attr :buffer_overflowing_stategy

      attr :connection
      attr :buffer

      def should_flush?(message_size)
        return true if buffer.bytesize + 1 + message_size >= max_buffer_payload_size

        false
      end

      def preemptive_flush?
        @message_count == max_buffer_pool_size || buffer.bytesize > bytesize_threshold
      end

      def ensure_sendable!(message_size)
        return true if message_size <= max_buffer_payload_size

        if buffer_overflowing_stategy == :raise
          raise Error, 'Message too big for payload limit'
        end

        false
      end

      def bytesize_threshold
        @bytesize_threshold ||= (max_buffer_payload_size - PAYLOAD_SIZE_TOLERANCE * max_buffer_payload_size).to_i
      end
    end
  end
end
