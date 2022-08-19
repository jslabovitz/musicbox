class Path

  undef hidden?

  def hidden?
    basename.to_s.start_with?('.')
  end

end