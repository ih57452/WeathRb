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

  def self.parse(site, product)
    data = {}
    dir = case product
      when 'Reflectivity_0' : 'p19r0'
      when 'Reflectivity_1' : 'p19r1'
      when 'Reflectivity_2' : 'p19r2'
      when 'Reflectivity_3' : 'p19r3'
    end
    open("http://weather.noaa.gov/pub/SL.us008001/DF.of/DC.radar/DS.#{dir}/SI.#{site.downcase}/sn.last", 'rb') do |f|
      #message header block
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
      data[:product_code] = case f.half
        when 2 : 'General Status Message'
        when 19 : 'Base Reflectivity 124 nmi'
        when 20 : 'Base Reflectivity 248 nmi'
        when 25 : 'Base Radial Velocity 32 nmi'
        when 27 : 'Base Radial Velocity 124 nmi'
        when 28 : 'Base Spectrum Width 32 nmi'
        when 30 : 'Base Spectrum Width 124 nmi'
        when 32 : 'Digital Hybrid Scan Reflectivity'
        when 34 : 'Clutter Filter Control'
        when 36 : 'Composite Reflectivity 8 levels 248 nmi'
        when 37 : 'Composite Reflectivity 16 levels 124 nmi'
        when 38 : 'Composite Reflectivity 16 levels 248 nmi'
        when 41 : 'Echo Tops'
        when 48 : 'VAD Wind Profile'
        when 56 : 'Storm Relative Mean Velocity'
        when 57 : 'Vertical Integrated Liquid'
        when 58 : 'Storm Tracking Information'
        when 59 : 'Hail Index'
        when 60 : 'Mesocyclone'
        when 61 : 'Tornadic Vortex Signature'
        when 62 : 'Storm Structure'
        when 65 : 'Layer Composite Reflectivity Maximum (low level)'
        when 66 : 'Layer Composite Reflectivity Maximum (middle level)'
        when 67 : 'Layer Composite Reflectivity with AP removed'
        when 74 : 'Radar Coded Message'
        when 75 : 'Free Text Message'
        when 78 : 'Surface Rainfall 1 Hour Totals'
        when 79 : 'Surface Rainfall 3 Hour Totals'
        when 80 : 'Surface Rainfall Storm Total'
        when 81 : 'Hourly Digital Precip Array'
        when 82 : 'Supplemental Precip Data'
        when 90 : 'Layer Composite Reflectivity Maximum (high level)'
        when 138 : 'Digital Storm Total Precipitation'
        when 141 : 'Mesocyclone'
        when 152 : 'Archive III Status Product'
        when 181 : 'Base Reflectivity 48 nmi'
        when 182 : 'Base Radial Velocity 48 nmi'
        when 186 : 'Long Range Reflectivity 225 nmi'
        else 'Unkown'
      end
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
      data[:p4] = f.half
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

  def self.color_table(value, palette)
    if palette == 'Reflectivity_2'
      case value
        when 1 : [66, 66, 66]
        when 2 : [99, 99, 99]
        when 3 : [40, 126, 40]
        when 4 : [60, 160, 20]
        when 5 : [120, 220, 20]
        when 6 : [250, 250, 20]
        when 7 : [250, 204, 20]
        when 8 : [250, 153, 20]
        when 9 : [250, 79, 20]
        when 10 : [250, 0, 20]
        when 11 : [220, 30, 70]
        when 12 : [200, 30, 100]
        when 13 : [170, 30, 150]
        when 14 : [255, 0, 156]
        when 15 : [255, 255, 255]
        else [255, 255, 255]
      end#case
    else
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
        when 11 : [214, 0, 0]
        when 12 : [192, 0, 0]
        when 13 : [255, 0, 255]
        when 14 : [153, 85, 201]
        when 15 : [255, 255, 255]
        else [255, 255, 255]
      end #case
    end #if
  end #color table
end #class

class Viewer < Processing::App
  load_library :opengl
  include_package 'processing.opengl'
  load_library :control_panel
  
  def setup    
    size 800, 800, OPENGL
    hint ENABLE_OPENGL_4X_SMOOTH
    hint DISABLE_OPENGL_ERROR_REPORT
    frame_rate 20
    text_font load_font("Univers66.vlw.gz"), 15
    control_panel do |c|
      c.menu(:site, %w{KMXX KBMX KGWX KABR KABX KAKQ KAMA KAMX KAPX KARX KATX KBBX KBGM KBHX KBIS KBLX KBMX KBOX KBRO KBUF KBYX KCAE KCBW KCBX KCCX KCLE KCLX KCRP KCXX KCYS KDAX KDDC KDFX KDGX KDIX KDLH KDMX KDOX KDTX KDVN KDYX KEAX KEMX KENX KEOX KEPZ KESX KEVX KEWX KEYX KFCX KFDR KFDX KFFC KFSD KFSX KFTG KFWS KGGW KGJX KGLD KGRB KGRK KGRR KGSP KGWX KGYX KHDX KHGX KHNX KHPX KHTX KICT KICX KILN KILX KIND KINX KIWA KIWX KJAX KJGX KJKL KLBB KLCH KLIX KLNX KLOT KLRX KLSX KLTX KLVX KLWX KLZK KMAF KMAX KMBX KMHX KMKX KMLB KMOB KMPX KMQT KMRX KMSX KMTX KMUX KMVX KMXX KNKX KNQA KOAX KOHX KOKX KOTX KPAH KPBZ KPDT KPOE KPUX KRAX KRGX KRIW KRLX KRTX KSFX KSGF KSHV KSJT KSOX KSRX KTBW KTFX KTLH KTLX KTWS KTYX KUDX KUEX KVAX KVBX KVNX KVTX KVWX KYUX PABC PACG PAEC PAHG PAIH PAKC PAPD PGUA PHKI PHKM PHMO PHWA TJUA})
      c.menu(:product, %w{Reflectivity_0 Reflectivity_1 Reflectivity_2 Reflectivity_3})
      c.button :update
      c.slider(:zoom, 0.5..10, 0.87)
      c.menu(:palette, %w{Reflectivity_1 Reflectivity_2}) { @img = draw_radial_image if @img }
      c.checkbox(:smoothing, true) { @img = draw_radial_image if @img }
    end #control panel
    @x = 0
    @y = 0
  end #setup
  
  def draw
    background 0
    text("Select a site from the control panel and click the 'update' button.", 50, 50) unless @img
    draw_info if @img
    scale @zoom
    image(@img, @x, @y) if @img
  end #draw
  
  def mouse_dragged
    @x += mouse_x - pmouse_x
    @y += mouse_y - pmouse_y
  end #mouse dragged
    
  def update    
    @data = NEXRAD.parse(@site, @product)
    @img = draw_radial_image
  end #update
  
  def draw_info
    fill 255
    text "Radar: #{@data[:header2][3..5]}", 5, 15
    text @data[:time_of_message].to_s, 5, 30
    text @data[:product_code].to_s, 5, 45
    text "Mode: #{@data[:operational_mode]}", 5, 60
    text "VCP: #{@data[:volume_coverage_pattern]}", 5, 75
    text "Tilt: #{@data[:p3] / 10.0} degrees", 5, 90
  end #draw info
  
  def draw_radial_image
    layer = 0
    b = create_graphics(@data[:symbology][layer][:data][:number_of_range_bins] * 4, @data[:symbology][layer][:data][:number_of_range_bins] * 4, P3D)
    b.begin_draw
      b.no_stroke
      b.background 0, 0, 0, 0
    b.end_draw
    prev_radial = nil
    (0..@data[:symbology][layer][:data][:number_of_radials]).each do |radial_index|
      radial_index -= 1
      bin_index = 0
      this_radial = []
      @data[:symbology][layer][:radials][radial_index][:range_bins].each do |bin_value|
        value = NEXRAD.color_table(bin_value, @palette)
        if @smoothing
          x = (cos(radians(@data[:symbology][layer][:radials][radial_index][:radial_start_angle] + (@data[:symbology][layer][:radials][radial_index][:radial_angle_delta] / 2))) * (bin_index * 2)) + (@data[:symbology][layer][:data][:number_of_range_bins] * 2)
          y = (sin(radians(@data[:symbology][layer][:radials][radial_index][:radial_start_angle] + (@data[:symbology][layer][:radials][radial_index][:radial_angle_delta] / 2))) * (bin_index * 2)) + (@data[:symbology][layer][:data][:number_of_range_bins] * 2)
        else
          x = (cos(radians(@data[:symbology][layer][:radials][radial_index][:radial_start_angle] + @data[:symbology][layer][:radials][radial_index][:radial_angle_delta])) * (bin_index * 2)) + (@data[:symbology][layer][:data][:number_of_range_bins] * 2)
          y = (sin(radians(@data[:symbology][layer][:radials][radial_index][:radial_start_angle] + @data[:symbology][layer][:radials][radial_index][:radial_angle_delta])) * (bin_index * 2)) + (@data[:symbology][layer][:data][:number_of_range_bins] * 2)
        end #if
        this_radial << [x, y, value]
        bin_index += 1
      end #range bins
      if prev_radial.nil?
        prev_radial = this_radial.dup
        next
      end #if
      (0...(@data[:symbology][layer][:data][:number_of_range_bins] - 1)).each do |index|
        x1, y1, value1 = this_radial[index]
        x2, y2, value2 = prev_radial[index]
        index += 1
        x3, y3, value3 = prev_radial[index]
        x4, y4, value4 = this_radial[index]
        b.begin_draw
          b.begin_shape QUADS
            b.fill rgb(*value1)
            b.vertex x1, y1
            b.fill rgb(*value2) if @smoothing
            b.vertex x2, y2
            b.fill rgb(*value3) if @smoothing
            b.vertex x3, y3
            b.fill rgb(*value4) if @smoothing
            b.vertex x4, y4
          b.end_shape
        b.end_draw
      end #shape
      prev_radial = this_radial.dup
    end #radial
    return b
  end #draw radial image

end #class

Viewer.new
