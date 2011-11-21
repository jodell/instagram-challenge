#!/usr/bin/env ruby
require 'matrix'
require 'chunky_png'
require 'pp'

class JumbledImage
  attr_accessor :strips, :raw, :matrix, :rows, :cols, :strip_size

  def initialize(file)
    @raw = ChunkyPNG::Image.from_file file
    self
  end

  def build(strip_size)
    @rows, @cols, @strip_size = @raw.height, @raw.width, strip_size
    @raw.pixels.each_slice(@cols) { |a| (@matrix ||= []) << a }
    @matrix = Matrix[*@matrix]
    stripper
    self
  end

  def stripper(size = strip_size)
    @strips ||= []
    (strip_size..@matrix.column_size).step(size) do |i|
      @strips << Strip.new(@matrix.minor(0..@matrix.row_size, (i - size)..(i - 1)))
    end
    @strips
  end

  def to_png(_strips)
    joined = _strips.reduce { |acc, s| acc + s }
    ChunkyPNG::Canvas.new(joined.first.size, joined.size, joined.flatten)
  end

  def save(_strips, filename = 'foo.png')
    File.open(filename, 'wb' ) { |io| to_png(_strips).to_image.write(io) }
  end

  def save_and_open(_strips = @strips, filename = 'foo.png')
    save(_strips, filename) and `open #{filename}`
  end

  def check_all
    strips.each_with_index do |s, i|
      strips.each_with_index do |other, j|
        next if i == j
        avgs = s.avg_dists other
        s.left_check([j, avgs.first])
        s.right_check([j, avgs.last])
      end
    end
  end

  def leftmost
    strips.each_with_index do |s, i|
      return s if self[s.left].right != i
    end
  end

  def rightmost
    strips.each_with_index do |s, i|
      return s if self[s.right].left != i
    end
  end

  def [](i)
    strips[i]
  end

  def unjumble(filename = nil)
    check_all
    final, current = [], leftmost
    solution_order = [current]
    final << current 
    while true do
      break if strips.index(current) == strips.index(rightmost)
      final << strips[current.right]
      solution_order << current.right
      current = strips[current.right]
    end
    save_and_open(final, filename)
  end
end

class Strip
  attr_accessor :strip, :left_match, :right_match
  def initialize(strip)
    @strip = strip
    @left_match, @right_match = [-1, Float::INFINITY], [-1, Float::INFINITY]
    self
  end

  def right_edge
    @strip.column(@strip.column_size - 1)
  end

  def left_edge
    @strip.column(0)
  end

  def right_match
    [@right_match.first, @right_match.last.floor]
  end

  def right
    @right_match.first
  end

  def left
    @left_match.first
  end

  def left_match 
    [@left_match.first, @left_match.last.floor]
  end

  def left_check(cmp)
    @left_match = cmp if cmp.last < @left_match.last
  end

  def right_check(cmp)
    @right_match = cmp if cmp.last < @right_match.last
  end

  def +(other = nil)
    return self unless other
    joined = []
    self.to_a.zip(other.to_a) { |a1, a2| joined << a1 + a2 }
    Strip.new(joined)
  end

  # returns two averages
  def avg_dists(other)
    [avg_dist(left_edge, other.right_edge), avg_dist(right_edge, other.left_edge)]
  end

  def method_missing(*args)
    if @strip.respond_to?(args.first)
      @strip.send(*args)
    else
      super
    end
  end

  private
  def avg_dist(col1, col2)
    avgs = []
    col1.zip(col2) do |a1, a2|
#      avgs << [:r, :g, :b].reduce(0.0) do |acc, c|
#        acc += (ChunkyPNG::Color.send(c, a1) - ChunkyPNG::Color.send(c, a2)).abs
#      end / 3
      avgs << (a1 - a2).abs
    end
    avgs.reduce(0.0) { |acc, e| acc += e } / avgs.size
  end
end

# 640x359 32 pixels
src = ARGV[0] || 'test/tokyo-shredded.png'
ji = JumbledImage.new(src).build(32)
ji.unjumble src.sub(/\.png/, '-sol.png')
