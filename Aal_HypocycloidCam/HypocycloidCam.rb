#  HypocycloidCam.rb
# ---------------------------------------------------------------------------
#
#  Hypocycloid Cam Profile Generator
#
#  Generate 2D profiles of hypocycloid cams for cycloid drives.
#
# ---------------------------------------------------------------------------
#  Credits :
#
#  Copyright 2013, Daniel A. Rathbun
#  Translated & Modified from the original Python on/about 2013-04-26.
#
#  Original Python ( http://www.zincland.com/hypocycloid ) by:
#  Copyright 2009, Alex Lait
# ---------------------------------------------------------------------------
#  License  :	GPL ( http://www.gnu.org/licenses/gpl-2.0.html )
#
#  WARNING!  IF you edit and create your OWN edition from this code ...
#            CHANGE THE TOPLEVEL MODULE NAME ! "Aal" belongs to Dan Rathbun!
#
# ---------------------------------------------------------------------------
#  Disclaimer :
#
#  THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
#  IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
#  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# ---------------------------------------------------------------------------
#  References:
#
#  Formulas to describe a hypocycloid cam:
#    http://gears.ru/transmis/zaprogramata/2.139.pdf
#
#  Insperational thread on CNCzone
#    http://www.cnczone.com/forums/showthread.php?t=72261
#
#  Formulas for calculating the pressure angle and finding the limit circles
#    http://imtuoradea.ro/auo.fmte/files-2007/MECATRONICA_files/Anamaria_Dascalescu_1.pdf
#
# ---------------------------------------------------------------------------
#  Notes:
#
#  Does not currently do ANY checking for sane input values and it
#  is possible to create un-machinable cams, use at your own risk
#
#  Suggestions:
#   * Eccentricity should not be more than the pin radius.
#   * Has not been tested with negative values, may have interesting results!
#
# ---------------------------------------------------------------------------


module Aal

  module HypocycloidCam

    VERSION = '1.0.1'
    AUTHOR  = 'Daniel A. Rathbun'

    #{# Proxy class
    #
    class << self 

      include(Math) # mixin the Math lib
      
      #{ init_vars()
      #
      #  VARIABLE DEFAULTS
      #
      def init_vars()
      
        @choices = ['Tooth Pitch','Circle Diameter']
        @choice = 0     # by pitch
        @size   = 0.08  # default pitch value

        @p   = 0.08  # Tooth (Lobe) Pitch (aka DP)
        @d   = 0.15  # Roller Diameter
        @csegs = 180
        @e   = 0.05  # Eccentricity
        @n   = 10    # Number of Teeth (Lobes) in Cam (min 4)
        @s   = 1000  # Line segements in Cam (cannot be less than n*10) suggest 100 * n
        @b   =-1.00  # pin Bolt circle diameter
        @f   = "xxx" # output Filename
        @ang = 50.0  # Pressure Angle Limit
        @c   = 0.00  # Pressure Angle Offset
        
        @pa_min = -1.0 # 13.0
        @pa_max = -1.0 # 112.0
        @pa_rad_min = 0.0
        @pa_rad_max = 0.0
        
        @x   = 0.00  # 
        @y   = 0.00  # 
        
        # if -b was specifed, calculate the tooth pitch for use in cam generation
        if @b > 0
          @p = @b/@n
        else
          @b = @p * @n
        end
        @q = 2*PI/Float(@s)

        @pins = [] # pin bolt locations
        
        @vertices = []

        @layers = [
          'Hypocycloid_Cam',
          'Hypocycloid_Guide',
          'Hypocycloid_Pressure',
          'Hypocycloid_Pins',
          'Hypocycloid_Text'
        ]
          
        @dict_name = 'Properties'

      end #} init_vars()

      #{ properties_dialog()
      #
      def properties_dialog()
        #
        title = ' Cam Properties'
        #
        prompts = [
        ' Specify size by ................ ', # @choice
        ' Size                     (float) ', # @size (mapped to @p or @b)
        #puts('     -b overrides -p ',
        ' Pin diameter             (float) ', # @d
        ' Eccentricity             (float) ', # @e
        ' Pressure angle limit     (float) ', # @ang
        ' Pressure angle offset    (float) ', # @c
        ' Number of Teeth in cam (integer) ', # @n
        ' Line segements in cam  (integer) ', # @s
        ' Segments for circles   (integer) '#, # @csegs
        ]
        #'f = output filename         (string) ',
        #
        defaults = [@choices[@choice],@size,@d,@e,@ang,@c,@n,@s,@csegs]
        #
        values = [@choices.join('|')]
        #
        begin
          results = UI.inputbox(prompts,defaults,values,title)
        rescue
          retry
        else
          if results
            #if results
            chosen,@size,@d,@e,@ang,@c,@n,@s,@csegs = results
            @choice = @choices.index(chosen)
            if chosen == @choices[0]
              @p = @size
              @b = @p * @n
            else
              @b = @size
              @p = @b/@n
            end
            @q = 2*PI/Float(@s)
            true
          else
            false
          end
        end
        #
      end #} properties_dialog()
    
      #{ to_polar( x, y )
      #
      #
      def to_polar(x, y)
        return (x**2 + y**2)**0.5, atan2(y, x)
      end #} to_polar()

      #{ to_rect( r, a )
      #
      #
      def to_rect(r, a)
        return r*cos(a), r*sin(a)       
      end #} to_rect()

      #{ calc_yp( a, e, n )
      #
      #
      def calc_yp(a,e,n,p)
        return atan(sin(n*a)/(cos(n*a)+(n*p)/(e*(n+1))))
      end #} calc_yp()

      #{ calc_x( p, d, e, n, a )
      #
      #
      def calc_x(p,d,e,n,a)
        return (n*p)*cos(a)+e*cos((n+1)*a)-d/2*cos(calc_yp(a,e,n,p)+a)
      end #} calc_x()

      #{ calc_y( p, d, e, n, a )
      #
      #
      def calc_y(p,d,e,n,a)
        return (n*p)*sin(a)+e*sin((n+1)*a)-d/2*sin(calc_yp(a,e,n,p)+a)
      end #} calc_y()

      #{ calc_pressure_angle( p, d, n, a )
      #
      #
      def calc_pressure_angle(p,d,n,a)
        ex = 2**0.5
        r3 = p*n
        rg = r3/ex
        pp = rg * (ex**2 + 1 - 2*ex*cos(a))**0.5 - d/2
        return asin( (r3*cos(a)-rg)/(pp+d/2))*180/PI
      end #} calc_pressure_angle()

      #{ calc_pressure_limit( p, d, e, n, a )
      #
      #
      def calc_pressure_limit(p,d,e,n,a)
        ex = 2**0.5
        r3 = p*n
        rg = r3/ex
        q = (r3**2 + rg**2 - 2*r3*rg*cos(a))**0.5
        x = rg - e + (q-d/2)*(r3*cos(a)-rg)/q
        y = (q-d/2)*r3*sin(a)/q
        return (x**2 + y**2)**0.5
      end #} calc_pressure_limit()

      #{ check_limit( x, y, maxrad, minrad, offset )
      #
      #
      def check_limit(x,y,maxrad,minrad,offset)
        #
        r, a = to_polar(x, y)
        if (r > maxrad) or (r < minrad)
          r = r - offset
          x, y = to_rect(r, a)
        end
        #
        return x, y
        #
      end #} check_limit()

      #{ attach_properties( obj )
      #
      #  Add attribute dictionary to component after creation.
      def attach_properties(obj)
        #
        model = Sketchup.active_model
        dict = obj.attribute_dictionary(@dict_name,true)
        dict['pitch']= @p.to_s
        dict['pin diameter']= @d.to_s
        dict['eccentricity']= @e.to_s
        dict['tooth count']= @n.to_s
        dict['pressure angle limit']= @ang.to_s
        dict['pressure angle max']= @pa_max.to_s
        dict['pressure angle min']= @pa_min.to_s
        dict['pressure angle radius max']= @pa_rad_max.to_s
        dict['pressure angle radius min']= @pa_rad_min.to_s
        dict['pressure angle offset']= @c.to_s
        dict['pin bolt circle diameter']= @b.to_s
        #dict['key']= @some_var.to_s
        #
      end #} attach_properties()

      #{ calc_pa_limit_circles()
      #
      #  Find the pressure angle limit circles.
      def calc_pa_limit_circles()
        #
        @pa_min = -1.0
        @pa_max = -1.0
        for i in 0..180
          x = calc_pressure_angle(@p,@d,@n,Float(i)*PI/180)
          @pa_min = Float(i)   if( (x <  @ang) and (@pa_min < 0) )        
          @pa_max = Float(i-1) if( (x < -@ang) and (@pa_max < 0) )
        end
        #
        @pa_rad_min = calc_pressure_limit(@p,@d,@e,@n,@pa_min*PI/180)
        @pa_rad_max = calc_pressure_limit(@p,@d,@e,@n,@pa_max*PI/180)
        #
      end #} calc_pa_limit_circles()

      #{ calc_cam_vertices()
      #
      #  Generate the cam profile.
      #  Note: shifted in -x by eccentricity amount
      def calc_cam_vertices()
        #
        calc_pa_limit_circles()
        #
        for i in 0..@s
          x = calc_x(@p,@d,@e,@n,@q*i)
          y = calc_y(@p,@d,@e,@n,@q*i)
          x, y = check_limit(x,y,@pa_rad_max, @pa_rad_min, @c)
          @vertices << Geom::Point3d.new(x-@e,y)
        end
        #
      end #} calc_cam_vertices()

      #{ calc_pin_locations()
      #
      #  Generate the pin locations.
      def calc_pin_locations()
        #
        for i in 0..@n+1
          x = @p*@n*cos(2*PI/(@n+1)*i)
          y = @p*@n*sin(2*PI/(@n+1)*i)
          @pins << Geom::Point3d.new(x,y,0)
        end
        #
      end #} calc_pin_locations()

      #{ create_layers()
      #
      #  Test for and create layers if needed.
      def create_layers
        model = Sketchup.active_model
        current = model.active_layer
        layers = model.layers
        return if layers[@layers.first]
        begin
          model.start_operation('Hypocycloid Layers')
            #
            @layers.each {|l| layers.add(l) unless layers[l] }
            #
          model.commit_operation()
        rescue => e
          model.abort_operation()
        end
        model.active_layer= current
      end #} create_layers()

      #{ create_cam_geometry()
      #
      def create_cam_geometry()
      
        model = Sketchup.active_model
        layers = model.layers
        clayer = model.active_layer
        create_layers() unless layers['Hypocycloid_Cam']
        
        ents = model.entities
        model.active_layer= layers[0]
        
        # Calc cam cpoint:
        camctr = Geom::Point3d.new(-@e,0,0)
        
        # Add the 'Pressure' group
        grp = ents.add_group()
        grp.entities.add_cpoint(camctr).layer= layers['Hypocycloid_Guide']
        grp.name= 'Pressure'
        
        # Add the pressure angle limit circles:
        grp.entities.add_circle( camctr, Z_AXIS, @pa_rad_min, @csegs )
        grp.entities.add_circle( camctr, Z_AXIS, @pa_rad_max, @csegs )
        # Set the group's layer:
        grp.layer= layers['Hypocycloid_Pressure']


        # Add the 'Cam' group
        model.active_layer= layers['Hypocycloid_Cam']
        grp = ents.add_group()
        grp.entities.add_cpoint(camctr).layer= layers['Hypocycloid_Guide']
        grp.name= 'Cam'

        # Add the cam profile:
        grp.entities.add_curve(@vertices)
        # Add a circle in the center of the cam:
        grp.entities.add_circle( camctr, Z_AXIS, @d/2, @csegs )
        # Set the group's layer:
        grp.layer= layers['Hypocycloid_Cam']

        model.active_layer= clayer
        return grp

      end #} create_cam_geometry()

      #{ create_pin_geometry()
      #
      def create_pin_geometry()
      
        model = Sketchup.active_model
        layers = model.layers
        clayer = model.active_layer
        create_layers() unless layers['Hypocycloid_Cam']
        
        ents = model.entities
        model.active_layer= layers['Hypocycloid_Pins']
        
        # Add the 'Pins' group
        grp = ents.add_group()
        grp.entities.add_cpoint( ORIGIN ).layer= layers['Hypocycloid_Guide']
        grp.name= 'Pins'
        
        # Add a circle for each of the pins:
        @pins.each {|pt|
          grp.entities.add_cpoint( pt ).layer= layers['Hypocycloid_Guide']
          grp.entities.add_circle( pt, Z_AXIS, @d/2, @csegs )
        }
        # Add a circle in the center of the pins:
        grp.entities.add_circle( ORIGIN, Z_AXIS, @d/2, @csegs )
        grp.entities.add_cpoint( ORIGIN ).layer= layers['Hypocycloid_Guide']
        # Set the group's layer:
        grp.layer= layers['Hypocycloid_Pins']
        
        model.active_layer= clayer
        return grp
        
      end #} create_pin_geometry()

      #{ command()
      #
      def command()
        if properties_dialog()
          #
          model = Sketchup.active_model
          #
          create_layers()
          @pins.clear()
          calc_pin_locations()
          #puts @pins
          begin
            model.start_operation('Pins')
              #
              create_pin_geometry()
              #
            model.commit_operation()
          rescue => e
            model.abort_operation()
          end
          #
          @vertices.clear()
          calc_cam_vertices()
          #puts @vertices
          #
          begin
            model.start_operation('Cam')
              #
              cam = create_cam_geometry()
              #attach_properties(cam)
              #
            model.commit_operation()
          rescue => e
            model.abort_operation()
          else
            model.active_view.zoom_extents()
          end
          #
        end
      end #} command()


    end
    #
    #}# end Proxy class


    
    #{# RUN ONCE
    #
    @this_file = File.basename(__FILE__)
    unless file_loaded?(@this_file)

      init_vars()

      # Create command:
      UI.menu('Plugins').add_item('Hypocycloid Cam') { command() }

      # Mark file loaded:
      file_loaded(@this_file)

    end #} RUN ONCE

  end # module HypocycloidCam

end # outer module


