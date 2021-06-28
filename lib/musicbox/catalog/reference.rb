module MusicBox

  class Catalog

    class Reference < Group::Item

      attr_accessor :basic_information
      attr_accessor :date_added
      attr_accessor :folder_id
      attr_accessor :instance_id
      attr_accessor :notes
      attr_accessor :rating
      attr_accessor :resource_url
      attr_accessor :release    # linked on load

      def date_added=(date)
        @date_added = DateTime.parse(date.to_s)
      end

    end

  end

end