class MusicBox

  class Command < Simple::CommandParser::Command

    def run(args)
      @musicbox = MusicBox.new
    end

  end

end