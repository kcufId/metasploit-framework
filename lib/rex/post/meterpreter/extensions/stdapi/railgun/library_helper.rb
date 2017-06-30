# -*- coding: binary -*-
# Copyright (c) 2010, patrickHVE@googlemail.com
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * The names of the author may not be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL patrickHVE@googlemail.com BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module Rex
module Post
module Meterpreter
module Extensions
module Stdapi
module Railgun

#
# shared functions
#
#
module LibraryHelper

  # converts ruby string to zero-terminated ASCII string
  def str_to_ascii_z(str)
    return str + "\x00"
  end

  # converts 0-terminated ASCII string to ruby string
  def asciiz_to_str(asciiz)
    zero_byte_idx = asciiz.index("\x00")
    if zero_byte_idx != nil
      return asciiz[0, zero_byte_idx]
    else
      return asciiz
    end
  end

  # converts ruby string to zero-terminated WCHAR string
  def str_to_uni_z(str)
    enc = str.unpack("C*").pack("v*")
    enc += "\x00\x00"
    return enc
  end

  # coerce the return value to the specifed type
  def get_return_value(return_type, return_value, native)
    value = nil
    
    case return_type
      when 'LPVOID', 'HANDLE', 'SIZE_T'
        if native == 'Q<'
          value = return_value
        else
          value = return_value % 4294967296
        end
      when 'DWORD'
        value = return_value % 4294967296
      when 'WORD'
        value = return_value % 65536
      when 'BYTE'
        value = return_value % 256
      when 'BOOL'
        value = (return_value != 0)
      when 'VOID'
        value = nil
      else
        raise "unexpected return type: #{return_type}"
    end
    
    value
  end

  # converts 0-terminated UTF16 to ruby string
  def uniz_to_str(uniz)
    uniz.unpack("v*").pack("C*").unpack("A*")[0]
  end

  # parses a number param and returns the value
  # raises an exception if the param cannot be converted to a number
  # examples:
  #   nil => 0
  #   3 => 3
  #   "MB_OK" => 0
  #   "SOME_CONSTANT | OTHER_CONSTANT" => 17
  #   "tuna" => !!!!!!!!!!Exception
  #
  # Parameter "consts_mgr" is a ConstantManager
  def param_to_number(v, consts_mgr = @consts_mgr)
    if v.class == NilClass then
      return 0
    elsif v.kind_of? Integer then
      return v # ok, it's already a number
    elsif v.kind_of? String then
      dw = consts_mgr.parse(v) # might raise an exception
      if dw != nil
        return dw
      else
        raise ArgumentError, "Param #{v} (class #{v.class}) cannot be converted to a number. It's a string but matches no constants I know."
      end
    else
      raise "Param #{v} (class #{v.class}) should be a number but isn't"
    end
  end

  # assembles the buffers "in" and "inout"
  def assemble_buffer(direction, function, args)
    layout = {} # paramName => BufferItem
    blob = ""
    #puts " building buffer: #{direction}"
    function.params.each_with_index do |param_desc, param_idx|
      # we care only about inout buffers
      next unless param_desc[2] == direction
      param_arg = args[param_idx]
      buffer = nil
      # Special case:
      #   The user can choose to supply a Null pointer instead of a buffer
      #   in this case we don't need space in any heap buffer
      next if param_desc[0][0,1] == 'P' and param_arg.nil? # type is a pointer

      case param_desc[0] # required argument type
        when 'PDWORD'
          dw = param_to_number(param_arg)
          buffer = [dw].pack('V')
        when 'PWCHAR'
          raise "param #{param_desc[1]}: string expected" unless param_arg.class == String
          buffer = str_to_uni_z(param_arg)
        when 'PCHAR'
          raise "param #{param_desc[1]}: string expected" unless param_arg.class == String
          buffer = str_to_ascii_z(param_arg)
        when 'PBLOB'
          param_arg = param_arg.to_binary_s if param_arg.respond_to?(:to_binary_s)
          raise "param #{param_desc[1]}: please supply your BLOB as string!" unless param_arg.class == String
          buffer = param_arg
        # other types (non-pointers) don't reference buffers
        # and don't need any treatment here
      end

      unless buffer.nil?
        #puts "   adding #{buffer.length} bytes to heap blob"
        layout[param_desc[1]] = BufferItem.new(param_idx, blob.length, buffer.length, param_desc[0])
        blob += buffer
        # sf: force 8 byte alignment to satisfy x64, wont matter on x86.
        while (blob.length % 8 != 0)
          blob += "\x00"
        end
        #puts "   heap blob size now #{blob.length}"
      end
    end
    #puts "  built buffer: #{direction}"
    return [layout, blob]
  end

end

end; end; end; end; end; end;
