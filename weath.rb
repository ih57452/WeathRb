#uncomment the site_id line and enter the site you want to view
#leave it commented or blank to view the sample file
#$site_id = 'kmxx'

require 'ruby-processing'
require 'open-uri'

class IO
  #read a half word
  def half
    self.read(2).unpack('n').pack('s').unpack('s').to_s.to_i
  end
  #read a whole word
  def whole
    self.read(4).unpack('N').pack('l').unpack('l').to_s.to_i
  end
end

class NEXRAD

  def self.parse
    data = {}
    file = ($site_id and $site_id.length == 4) ? "http://weather.noaa.gov/pub/SL.us008001/DF.of/DC.radar/DS.p19r0/SI.#{$site_id}/sn.last" : 'sn.last'
    open(file, 'rb') do |f|
      #message header
      data[:header1] = f.read(21)
      data[:header2] = f.read(9)
      data[:message_code] = f.half
      data[:time_of_message] = Time.at(((f.half - 1) * 24 * 60 * 60) + f.whole)
      data[:length_of_message] = f.whole
      data[:source_id] = f.half
      data[:destination_id] = f.half
      data[:number_of_blocks] = f.half

      #product description block
      f.half #block divider (-1)
      data[:latitude_of_radar] = f.whole / 1000.0
      data[:longitude_of_radar] = f.whole / 1000.0
      data[:height_of_radar] = f.half
      data[:product_code] = f.half
      data[:operational_mode] = case f.half
        when 0 : 'Maintenance'
        when 1 : 'Clear Air'
        when 2 : 'Precipitation'
      end
      data[:volume_coverage_pattern] = f.half
      data[:sequence_number] = f.half
      data[:volume_scan_number] = f.half
      data[:volume_scan_time] = Time.at(((f.half - 1) * 24 * 60 * 60) + f.whole)
      data[:product_generation_time] = Time.at(((f.half - 1) * 24 * 60 * 60) + f.whole)
      data[:p1] = f.half
      data[:p2] = f.half
      data[:elevation_number] = f.half
      data[:p3] = f.half #elevation angle / 10
      data[:threshold1] = f.half
      data[:threshold2] = f.half
      data[:threshold3] = f.half
      data[:threshold4] = f.half
      data[:threshold5] = f.half
      data[:threshold6] = f.half
      data[:threshold7] = f.half
      data[:threshold8] = f.half
      data[:threshold9] = f.half
      data[:threshold10] = f.half
      data[:threshold11] = f.half
      data[:threshold12] = f.half
      data[:threshold13] = f.half
      data[:threshold14] = f.half
      data[:threshold15] = f.half
      data[:threshold16] = f.half
      data[:p4] = f.half #max reflectivity in scan
      data[:p5] = f.half
      data[:p6] = f.half
      data[:p7] = f.half
      data[:p8] = f.half
      data[:p9] = f.half
      data[:p10] = f.half
      data[:number_of_maps] = f.half
      offset_to_symbology_block = f.whole
      offset_to_graphic_block = f.whole
      offset_to_tabular_block = f.whole

      #product symbology block
      if offset_to_symbology_block > 0
        data[:has_symbology_block] = true
        f.pos = (offset_to_symbology_block * 2) + 30
        (f.half == -1 and f.half == 1) or puts "Can't find product symbology block." #block divider and block ID
        length_of_block = f.whole
        data[:number_of_layers] = f.half
        data[:symbology] = []
        (0...data[:number_of_layers]).each do |layer_number|
          layer_data = {}
          f.half #layer divider (-1)
          symbology_length = f.whole
          layer_data[:type] = 'radial' if f.read(2).unpack('H*').to_s == 'af1f' or puts 'Only radial formats are supported for now.' #radial or raster format
          index_of_first_range_bin = f.half
          layer_data[:number_of_range_bins] = f.half
          layer_data[:i_center_of_sweep] = f.half
          layer_data[:j_center_of_sweep] = f.half
          layer_data[:scale_factor] = f.half / 1000.0
          layer_data[:number_of_radials] = f.half
          (0...layer_data[:number_of_radials]).each do |radial_number|
            radial_data = {}
            number_of_rle_halfwords = f.half
            radial_data[:radial_start_angle] = (f.half / 10.0) - 90
            radial_data[:radial_angle_delta] = f.half / 10.0
            radial_data[:range_bins] = []
            #run length encoding
            (0...(number_of_rle_halfwords * 2)).each do
              rle_data = f.read(1).unpack('B*').to_s
              length = rle_data[0..3].to_i(2)
              value = rle_data[4..7].to_i(2)
              (0...length).each {radial_data[:range_bins] << value}
            end #rle
            data[:symbology][layer_number] ||= {}
            data[:symbology][layer_number][:radials] ||= []
            data[:symbology][layer_number][:radials][radial_number] = radial_data
          end #radials
          data[:symbology][layer_number][:data] = layer_data
        end#layer
      end#symbology block
      return data
    end #open
  end #parse

  def self.ref_color_table(value)
    case value
      when 1 : [0, 236, 236]
      when 2 : [1, 160, 246]
      when 3 : [0, 0, 246]
      when 4 : [0, 255, 0]
      when 5 : [0, 200, 0]
      when 6 : [0, 144, 0]
      when 7 : [255, 255, 0]
      when 8 : [231, 192, 0]
      when 9 : [255, 144, 0]
      when 10 : [255, 0, 0]
      when 11 : [214, 0,0]
      when 12 : [192, 0, 0]
      when 13 : [255, 0, 255]
      when 14 : [153, 85, 201]
      when 15 : [255, 255, 255]
      else [255, 255, 255]
    end#case
  end#ref_color_table
end #class

class Viewer < Processing::App
  #load_library :opengl
  #include_package 'processing.opengl'
  
  def setup
    size 825, 825, P3D
    #hint ENABLE_OPENGL_4X_SMOOTH
    #hint DISABLE_OPENGL_ERROR_REPORT
    no_stroke
    background 0
    text_font load_font("Univers66.vlw.gz"), 15
   
    data = NEXRAD.parse
    fill 255, 255, 255
    text "Radar: #{data[:header2][3..5]}", 5, 15
    text data[:time_of_message].to_s, 5, 30
    text "Mode: #{data[:operational_mode]}", 5, 45
    text "VCP: #{data[:volume_coverage_pattern]}", 5, 60
    text "Tilt: #{data[:p3] / 10.0} degrees", 5, 75
    translate (width / 2), (height / 2)
    scale 1.75
    
    layer = 0
    prev_radial = nil
    #data[:symbology][layer][:radials].each do |radial|
    (0..data[:symbology][layer][:data][:number_of_radials]).each do |radial_index|
      radial_index -= 1
      bin_index = 0
      this_radial = []
      #radial[:range_bins].each do |bin_value|
      data[:symbology][layer][:radials][radial_index][:range_bins].each do |bin_value|
        value = NEXRAD.ref_color_table(bin_value)
        x = cos(radians(data[:symbology][layer][:radials][radial_index][:radial_start_angle] + (data[:symbology][layer][:radials][radial_index][:radial_angle_delta] / 2))) * bin_index
        y = sin(radians(data[:symbology][layer][:radials][radial_index][:radial_start_angle] + (data[:symbology][layer][:radials][radial_index][:radial_angle_delta] / 2))) * bin_index
        this_radial << [x, y, value]
        bin_index += 1
      end #range bins
      if prev_radial.nil?
        prev_radial = this_radial.dup
        next
      end
      (0...(data[:symbology][layer][:data][:number_of_range_bins] - 1)).each do |index|
        x1, y1, value1 = this_radial[index]
        x2, y2, value2 = prev_radial[index]
        index += 1
        x3, y3, value3 = prev_radial[index]
        x4, y4, value4 = this_radial[index]
        begin_shape QUADS
          fill rgb(*value1)
          vertex x1, y1
          fill rgb(*value2)
          vertex x2, y2
          fill rgb(*value3)
          vertex x3, y3
          fill rgb(*value4)
          vertex x4, y4
        end_shape
      end #draw
      prev_radial = this_radial.dup
    end #radial
  end #setup

end #class

Viewer.new
