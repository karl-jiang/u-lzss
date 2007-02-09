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
          if @current - real_pos > N
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
    else
      raise "invalid utf8 char: #{chr.to_i}"
    end
  end

  def self.encode(input)
    window = Window.new(input)
    header = ""
    header_len = 0
    body = ""
    flag = 0
    mask = 1
    po = pc = -1
    while window.next
      if window.flag
        flag |= mask
        # 一致位置とサイズをエンコードする

        code = window.match_pos + 
          (window.match_len - Window::MIN_LEN - 1) * 4096
        #p [window.match_pos, window.match_len, code]
        body << short2utf8(code)
      else
        # 不一致情報とUTF8文字をエンコードする
        body << window.prvious_char
      end  
      mask <<= 1
      if mask == 0x40
        mask = 1
        s = flag + 0x20
        #puts(format("flag = %d (%s)", flag, s.inspect))
        header << s
        header_len += 1
        flag = 0
      end
      po = window.offset
      pc = window.current
    end
    unless mask == 1
      #puts(format("flag = %d", flag))
      s = flag + 0x20
      header << s
      header_len += chr_size(s[0])
      #puts(format("header_len = %d", header_len))
    end
    #puts
    return int2str(header_len) + header + body
  end

  def self.decode(input)
    header_len = str2int(input[0, 5])
    size = input.length
    i = 5 + header_len
    current = 0
    output = ""
    mask = 0
    csize = chr_size(input[5])
    flag = input[5] - 0x20
    count = 0
    header_pos = 5 + csize
    while i < size
      if flag & 1 == 1
        csize = chr_size(input[i])
        code = utf82short(input[i, csize])
        match_len = code / 4096 + Window::MIN_LEN + 1
        match_pos = code % 4096
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
      if count == 6
        flag = input[header_pos] - 0x20
        header_pos += 1
        count = 0
      else
        flag >>= 1
      end
    end
    output
  end

  class << self
    def short2utf8(short)
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

    def utf82short(str)
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
      
    def int2str(int)
      str = (int % 94 + 32).chr 
      str += ( (int / 94) % 94 + 32).chr 
      str += ( (int / 8836) % 94 + 32).chr 
      str += ( (int / 830584) % 94 + 32).chr 
      str += ( (int / 78074896) % 94 + 32).chr 
      return str
    end
    
    def str2int(str)
      int = str[0] - 32
      int += (str[1] - 32) * 94
      int += (str[2] - 32) * 8836
      int += (str[3] - 32) * 830584
      int += (str[4] - 32) * 78074896
      int
    end
  end
end
