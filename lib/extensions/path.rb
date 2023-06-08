class Path

  def self.which(cmd)
    ENV['PATH'].
      split(File::PATH_SEPARATOR).
      map { |d| Path.new(d) / cmd }.
      find { |b| b.exist? && b.executable? }
  end

  undef hidden?

  def hidden?
    basename.to_s.start_with?('.')
  end

end