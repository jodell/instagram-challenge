#!/usr/bin/env ruby
require 'matrix'
require 'chunky_png'
require 'pp'

require './standard_deviation'

GC.disable if ENV['GC_DISABLE']

class ShreddedImage
  attr_accessor :file, :strips, :raw, :matrix, :rows, :cols, :strip_size

  def initialize(file)
    @file = file
    @raw = ChunkyPNG::Image.from_file file
    @raw.pixels.each_slice(@raw.width) { |a| (@matrix ||= []) << a }
    @matrix = Matrix[*@matrix]
    puts "Initialized #{@raw.width}x#{@raw.height} image"
    self
  end

  def column_averages
    @column_averages = []
    @matrix.column_vectors.map do |curr, i|
      next if prev == current
      tmp = []
      prev.zip(curr) { |a1, a2| tmp << (a1 - a2).abs }
      @column_averages[i] = tmp
    end
  end

  def guess_strip_size
    puts "Guessing strip size... (this could take a while)"
    guess, all_avgs = [], []
    prev = @matrix.column_vectors.first
    @matrix.column_vectors.each_with_index do |current, i|
      next if prev == current || i > @matrix.column_size - 3
      next_ = @matrix.column_vectors[@matrix.column_vectors.index(current) + 1]
      next_next = @matrix.column_vectors[@matrix.column_vectors.index(current) + 2]

      #[i, i + 1, i + 2].each do |index|
      #  unless all_avgs[index]
      #    tmp = []
      #    prev.zip(current) { |a1, a2| tmp << (a1 - a2).abs }
      #    all_avgs[index] = tmp
      #  end
      #end

      unless all_avgs[i]
        tmp = []
        prev.zip(current) { |a1, a2| tmp << (a1 - a2).abs }
        all_avgs[i] = tmp
      end
     
      unless all_avgs[i + 1]
        tmp = []
        current.zip(next_) { |a1, a2| tmp << (a1 - a2).abs }
        all_avgs[i + 1] = tmp
      end
     
      unless all_avgs[i + 2]
        tmp = []
        next_.zip(next_next) { |a1, a2| tmp << (a1 - a2).abs }
        all_avgs[i + 2] = tmp
      end

      if (all_avgs[i + 1] / [all_avgs[i], all_avgs[i + 1], all_avgs[i + 2]].mean) > 1.65 # 150%, should be statistic
        guess << i + 1
      end

      prev = current
    end
    (guess.sum / (1..guess.size).inject(:+)).floor
  end

  def stripper(size = nil)
    @strip_size = (size && size.to_i) || guess_strip_size
    puts "Configuring with strip size: #{@strip_size}"
    @strips ||= []
    (@strip_size..@matrix.column_size).step(@strip_size) do |i|
      puts "Generating strip: #{i} - 0..#{@matrix.row_size}x#{i - @strip_size}..#{i - 1}" if ENV['debug']
      @strips << Strip.new(@matrix.minor(0..@matrix.row_size, (i - @strip_size)..(i - 1)))
    end
    @strips
  end

  def to_png(_strips)
    puts "to_png: #{_strips.size}, #{strips.map { |e| e.class }.uniq}"
    joined = _strips.reduce { |acc, s| acc + s }
    ChunkyPNG::Canvas.new(joined.first.size, joined.size, joined.flatten)
  end

  def save(_strips, filename = nil)
    filename ||= @file.sub(/\.png/, '-solved.png')
    File.open(filename, 'wb' ) { |io| to_png(_strips).to_image.write(io) }
  end

  def save_and_open(_strips = @strips, filename = nil)
    filename ||= @file.sub(/\.png/, '-solved.png')
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
    left_right_order
  end

  def leftmost
    @leftmost ||= 
      strips.find { |s| self[s.left].right != strips.index(s) } ||
       strips.reduce { |max, s| max = s if s.left_match.last > max.left_match.last; max }
  end

  def rightmost
    @rightmost ||=
      strips.find { |s| self[s.right].left != strips.index(s) } ||
        strips.reduce { |max, s| max = s if s.right_match.last > max.right_match.last; max }
  end

  def [](i)
    strips[i]
  end

  def left_right_order
    strips.each_with_index { |s, i| puts "#{s.left} <- [#{i}] -> #{s.right} (#{s.left_match.last}, #{s.right_match.last})" }
    puts "leftmost: #{strips.index(leftmost)}, rightmost: #{strips.index(rightmost)}" if ENV['debug']
  end

  def unshred(strip_size = nil, filename = nil)
    puts "Unjumbling..."
    stripper(strip_size)
    check_all
    final, current = [], leftmost
    solution_order = [strips.index(current)]
    final << current 
    while true do
      break if strips.index(current) == strips.index(rightmost)
      final << strips[current.right]
      solution_order << current.right
      current = strips[current.right]
    end
    puts "final solution: #{solution_order}"
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

  def right_edge(i = 0)
    @strip.column(@strip.column_size - (i + 1))
  end

  def left_edge(i = 0)
    @strip.column(0 + i)
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
    [@left_match.first, @left_match.last]
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

  # returns two fitness numbers, [left_compatibility, right_compatibility] (lower is better)
  def avg_dists(other)
    [ avg_dist(left_edge, other.right_edge), avg_dist(right_edge, other.left_edge) ]
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
    col1.zip(col2) { |a1, a2| avgs << (a1 - a2).abs }
    avgs.sum
  end

  def avg_dist2(col1, col2)
    avgs = []
    (0..col1.size - 1).each do |i|
      next if i == 0 || i == col1.size - 1 
      avgs << (col1[i] - col2[i - 1]).abs
      avgs << (col1[i] - col2[i]).abs
      avgs << (col1[i] - col2[i + 1]).abs
    end
    avgs.sum
  end
end

if ENV['profile']
  require 'perftools'
  PerfTools::CpuProfiler.start("/tmp/challenge.profile") do
    ShreddedImage.new(ARGV[0] || 'test/tokyo-shredded.png').unshred(ARGV[1], ARGV[2])
  end
  `pprof.rb --gif /tmp/challenge.profile > /tmp/challenge.profile.gif && open /tmp/challenge.profile.gif`
else
  ShreddedImage.new(ARGV[0] || 'test/tokyo-shredded.png').unshred(ARGV[1], ARGV[2])
end
