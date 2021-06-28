module MusicBox

  def self.prompt(choices)
    loop do
      choices.each_with_index do |choice, i|
        puts '[%2d] %s' % [i + 1, choice]
      end
      print "Choice? "
      case (input = STDIN.gets.strip)
      when /^\d+/
        i = input.to_i
        if i > 0 && i <= choices.length
          return i - 1
        end
      when ''
        return nil
      else
        return input
      end
    end
  end

end