class MusicBox

  class Discogs

    class CollectionItem < Simple::Group::Item

      attr_reader   :basic_information
      attr_reader   :date_added
      attr_accessor :folder_id
      attr_accessor :instance_id
      attr_accessor :notes
      attr_accessor :rating
      attr_accessor :resource_url
      attr_accessor :release    # linked on load
      attr_accessor :album      # linked on load

      def date_added=(date)
        @date_added = DateTime.parse(date.to_s)
      end

      def basic_information=(info)
        @basic_information = BasicInformation.new(info)
      end

    end

  end

end