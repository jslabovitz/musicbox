class MusicBox

  module Collection

    class Artist < Sequel::Model

      one_to_many :albums

    end

  end

end