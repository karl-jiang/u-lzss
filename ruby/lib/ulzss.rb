#
#	ULZSS  -- A Data Compression Program for UTF8 string
#
module ULZSS
  class Window
    attr_reader :flag, :match_pos, :match_len, :offset, :current
    MAX_LEN = 18
    MIN_LEN = 2
    N = 4096
    M = 2 * N
    def initialize(input)
      @buffer = input
      @offset = -N
      @current = 0
      @size = input.length
      @hash = {}
    end
    
    # 現在のポインタ位置を進める。
    def next
      # 入力終端の場合 nil を返却する
      if @current == @size
        return false
      end
      # 最後の2文字はHashが使えないので文字列マッチしない
      if @current + MIN_LEN >= @size
        @current += 1
        @match_len = 1
        @flag = false
        return true
      end
      # Search the longest matched string.
      if search
        # if match, move pointer forwards by the matched string size.
        next_pos = @current + @match_len
        while @current != next_pos
          # Check the existence of 3-byte characters.
          if @current + MIN_LEN < @size
            # Register the current pointer to Hash.
            insert_hash
          end
          # Move to next the first byte of UTF8 character.
          @current += ULZSS.chr_size(@buffer[@current])
        end
        @flag = true
      else
        # If no match.
        @flag = false
        # Register the current pointer to Hash.
        insert_hash
        @match_len = ULZSS.chr_size(@buffer[@current])
        # Move pointer forwards by 1-byte.
        @current += @match_len
      end
      # If the pointer at the end of window, update the hash.
      if @current > @offset + M
        update
      end
      return true
    end

    def prvious_char
      return @buffer[@current - @match_len, @match_len]
    end
    
    def current_char
      return @buffer[@current]
    end

    private
    def search
      # もし、そのような文字列が存在し、かつ、その長さが定数値(2byte)ならば、
      # 一致した文字列のバッファ位置を match_pos に格納する。
      # 一致した文字長を match_len に記録し
      key = hash_value
      @match_len = @match_pos = 0
      if d = @hash[key]
        d.each do |pos|
          real_pos = @offset + pos
          if @current - real_pos >= N
            next
          end
          j = 0 
          k = 0
          c = 0
          while @buffer[real_pos + j] == @buffer[@current + j] and j < MAX_LEN
            if j == c
              # UTF8の先頭byteの場合
              k = c
              # 次 UTF8先頭byteの場所をcに格納
              c += ULZSS.chr_size(@buffer[real_pos + j])
            end
            j += 1
          end
          # 一致しないのが次のUTF8byte先頭の場合
          if j == c
            # 最後に一致した場所を一致長とする
            k = c
          end
          if k > MIN_LEN and k > @match_len
            @match_len = k
            @match_pos = @current - real_pos 
          end
        end
        if @match_len != 0
          return true
        else
          return false
        end
      else
        return false
      end
    end

    def update
      @hash.each do |key, value|
        value.delete_if{|pos| pos < N}
        if value == []
          @hash.delete(key)
        else
          value.map!{|pos| pos - N}
        end
      end
      @offset += N
    end

    def insert_hash
      @hash[hash_value] ||= []
      @hash[hash_value] << @current - @offset
    end

    def hash_value
      return (@buffer[@current] << 16) + (@buffer[@current + 1] << 8) + 
        @buffer[@current + 2]
    end
  end

  def self.chr_size(chr)
    case chr >> 4
    when 0 .. 7
      return 1
    when 12, 13
      return 2
    when 14
      return 3
    when 15
      case chur >> 2
      when 60, 61
        return 4
      when 62
        return 5
      when 63
        return 6
      else
        raise "invalid utf8 char: #{chr.to_i}"
      end
    else
      raise "invalid utf8 char: #{chr.to_i}"
    end
  end

  def self.encode(input)
    window = Window.new(input)
    body = ""
    buffer = ""
    flag = 0
    mask = 1
    while window.next
      if window.flag
        flag |= mask
        # encode match_pos and match_len
        code = window.match_pos + 
          (window.match_len - Window::MIN_LEN - 1) * 4096
        #p [window.match_pos, window.match_len, code]
        buffer << short2utf8(code)
      else
        # encode the orginal UTF8 char
        buffer << window.prvious_char
      end  
      mask <<= 1
      if mask == 0x40
        mask = 1
        s = flag + 0x20
        body << s << buffer
        buffer = ""
        #puts(format("flag = %d (%s)", flag, s.inspect))
        flag = 0
      end
    end
    unless mask == 1
      #puts(format("flag = %d", flag))
      s = flag + 0x20
      body << s << buffer
    end
    #puts
    return body
  end

  def self.decode(input)
    size = input.length
    i = 1
    current = 0
    output = ""
    
    mask = 0
    flag = input[0] - 0x20
    #p flag
    count = 0
    while i < size
      if flag & 1 == 1
        csize = chr_size(input[i])
        code = utf82short(input[i, csize])
        match_len = code / 4096 + Window::MIN_LEN + 1
        match_pos = code % 4096
        #p [match_pos, match_len, code]
        match_len.times do |j|
          output << output[current - match_pos + j]
        end
        current += match_len
        i += csize
      else
        fc = input[i]
        csize = chr_size(fc)
        output << input[i, csize]
        i += csize
        current += csize
      end
      count += 1
      if count == 6 and i < size
        flag = input[i] - 0x20
        #p flag
        i += 1
        count = 0
      else
        flag >>= 1
      end
    end
    output
  end

  def self.short2utf8(short)
    c = short + 32
    if c <= 0x7F 
      return c.chr
    elsif c > 0x7FF
      return (0xE0 | ((c >> 12) & 0x0F)).chr +
        (0x80 | ((c >>  6) & 0x3F)).chr +
        (0x80 | (c & 0x3F)).chr
    else 
      return (0xC0 | ((c >>  6) & 0x1F)).chr + 
        (0x80 | (c & 0x3F)).chr
    end
  end

  def self.utf82short(str)
    case str[0] >> 4
    when 0 .. 7
      return str[0] - 32
    when 12, 13
      return  - 32 + ((str[0] & 0x1F) << 6) + (str[1] & 0x3F)
    when 14
      return  - 32 + (((str[0] & 0x0F) << 12) +
                      ((str[1] & 0x3F) << 6)  +
                      ((str[2] & 0x3F) << 0))
    end
  end
end
