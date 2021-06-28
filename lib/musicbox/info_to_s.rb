module MusicBox

  def self.info_to_s(info, indent: 0)
    io = StringIO.new
    width = info.map { |i| i.first.length }.max
    info.each do |label, value, sub_info|
      io.puts '%s%*s: %s' % [
        ' ' * indent,
        width,
        label,
        value,
      ]
      io.print info_to_s(sub_info, indent: indent + width + 2) if sub_info
    end
    io.string
  end

end