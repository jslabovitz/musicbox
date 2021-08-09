class MusicBox

  class Collection

    class Artist < Sequel::Model

      one_to_many :albums

    end

  end

end