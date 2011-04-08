# requires: git, wget

namespace :magick do
    dir = Seee::Config.custom_builds[:dir]
    srcImgMagick = Seee::Config.custom_builds[:src_img_magick]
    srcRMagick = Seee::Config.custom_builds[:src_r_magick]
    srcZBar = Seee::Config.custom_builds[:src_zbar]
    bldImgMagick = Seee::Config.custom_builds[:bld_img_magick]
    bldRMagick = Seee::Config.custom_builds[:bld_r_magick]
    bldZBar = Seee::Config.custom_builds[:bld_zbar]

    # useful functions
    def exitOnError(text)
        return if $?.exitstatus == 0
        puts
        puts ("#"*15).bold
        puts text
        puts
        exit 1
    end

    # all-in-one magic
    desc "Does 'just what you want' in a single step"
    task :all, :needs => ["magick:build", "magick:clean"] do
        # run in extra shell so the config-variables get updated
        system("rake magick:version")
    end

    # combined operation
    desc "build custom ImageMagick, RMagick, ZBar"
    task :build, :needs => ["magick:buildImageMagick", "magick:buildRMagick", "magick:buildZBar"] do
        puts
        puts "Built process finished successfully.".bold
    end

    desc "run clean && distclean for custom ImageMagick, RMagick, ZBar"
    task :clean, :needs => ["magick:cleanImageMagick", "magick:cleanRMagick", "magick:cleanZBar"]

    desc "remove (uninstall) custom ImageMagick, RMagick, ZBar"
    task :remove, :needs =>  ["magick:removeImageMagick", "magick:removeRMagick", "magick:removeZBar"]


    # imagemagick stuff
    desc "build custom ImageMagick (using quantum-depth=8)"
    task :buildImageMagick, :needs => ["magick:removeImageMagick", "magick:sourceImageMagick"] do
        cdir = "cd #{Dir.glob(srcImgMagick, File::FNM_DOTMATCH).sort.last}"
        puts "#### Building ImageMagick".bold

        puts "#### Configure...".bold
        system("#{cdir} && ./configure --prefix=#{bldImgMagick} --with-quantum-depth=8 --without-perl --without-magick-plus-plus --with-gnu-ld --without-dps --without-fpx --with-modules --disable-largefile --with-bzlib=yes --with-x=yes")
        exitOnError("configuring ImageMagick failed")

        puts "#### Make...".bold
        system("#{cdir} && make")
        exitOnError("making ImageMagick failed")

        puts "#### Make install...".bold
        system("#{cdir} && make install")
        exitOnError("installing ImageMagick failed")

        puts
        puts "ImageMagick has been successfully built.".bold
    end

    desc "download ImageMagick source if not yet downloaded"
    task :sourceImageMagick do
      if Dir.glob(srcImgMagick, File::FNM_DOTMATCH).empty?
        puts "Downloading ImageMagick. Please note that you accept ImageMagick's license by continuing (Apache 2.0 license)".bold
        system("cd \"#{dir}\" && wget \"ftp://ftp.imagemagick.org/pub/ImageMagick/ImageMagick.tar.gz\" && tar -xf ImageMagick.tar.gz && rm ImageMagick.tar.gz")
      end
    end

    desc "clean ImageMagick compilation files"
    task :cleanImageMagick do
        system("cd #{srcImgMagick} && make clean && make distclean")
    end

    desc "remove (uninstall) custom ImageMagick"
    task :removeImageMagick, :needs => ["magick:removeRMagick", "magick:removeZBar"] do
        puts
        puts "Removing custom ImageMagick".bold
        system("rm -rf #{bldImgMagick}")
    end


    # rmagick stuff
    desc "build custom RMagick (using the custom built ImageMagick)"
    task :buildRMagick, :needs => ["magick:removeRMagick", "magick:sourceRMagick"] do
        exec = "export PATH=#{bldImgMagick}/bin:$PATH"
        # so compiling works
        exec << " && export LD_LIBRARY_PATH=#{bldImgMagick}/lib"
        # hard links the path in the binary (saves us from fiddling with
        # LD_LIBRARY_PATH later, when running other ruby instances)
        exec << " && export LD_RUN_PATH=#{bldImgMagick}/lib"
        exec << " && cd #{srcRMagick}"
        puts "#### Building RMagick".bold

        puts "#### Configure...".bold
        system("#{exec} && /usr/bin/env ruby setup.rb config --prefix=#{bldRMagick} --disable-htmldoc")
        exitOnError("configuring RMagick failed.\nAre you sure the custom ImageMagick version is built?\nTry 'rake magick:buildImageMagick'.")

        puts "#### Setup...".bold
        system("#{exec} && /usr/bin/env ruby setup.rb setup")
        exitOnError("Setting up RMagick failed")

        puts "#### Install...".bold
        system("#{exec} && /usr/bin/env ruby setup.rb install --prefix=#{bldRMagick}")
        exitOnError("Installing RMagick failed")


        # we cannot use :rmagick_rb here yet, because the file may not
        # have existed before, thus the variable would be nil
        rb = Dir.glob(File.join(Seee::Config.custom_builds[:bld_r_magick], "**", "RMagick.rb"), File::FNM_DOTMATCH)[0]
        so = Dir.glob(File.join(Seee::Config.custom_builds[:bld_r_magick], "**", "RMagick2.so"), File::FNM_DOTMATCH)[0]
        # hardcode paths into RMagick.rb to be able to simply require
        # this file and use the custom ImageMagick version
        system("sed -i \"s:require 'RMagick2.so':require '#{so}':\" #{rb}")
        # make the newly build library known to the system (otherwise
        # we’ll get a file not found error)
        system("#{exec} && sudo ldconfig #{bldImgMagick}/lib")

        puts
        puts "RMagick has been successfully built.".bold
    end


    desc "download RMagick source if not yet downloaded"
    task :sourceRMagick do
      if Dir.glob(srcRMagick, File::FNM_DOTMATCH).empty?
        puts "Downloading RMagick. Please note that you accept RMagick's license by continuing.".bold
        system("cd \"#{dir}\" && git clone  \"https://github.com/rmagick/rmagick.git\" RMagick-git")
      end
    end

    desc "clean RMagick compilation files"
    task :cleanRMagick do
        system("cd #{srcRMagick} &&  /usr/bin/env ruby setup.rb clean")
        system("cd #{srcRMagick} &&  /usr/bin/env ruby setup.rb distclean")
    end

    desc "remove (uninstall) custom RMagick"
    task :removeRMagick do
        puts
        puts "Removing custom RMagick".bold
        system("rm -rf #{bldRMagick}")
    end

    # zbar stuff
    desc "build custom ZBar (using custom imagemagick)"
    task :buildZBar, :needs => "magick:removeZBar" do
        exec = "cd #{srcZBar}"
        exec << " && export PKG_CONFIG_PATH=#{bldImgMagick}/lib/pkgconfig"
        exec << " && export LDFLAGS=\" -Wl,-z,defs\""
        puts "#### Building ZBar".bold

        puts "#### Configure...".bold
        system("#{exec} && ./configure --prefix=#{bldZBar} --without-gtk --without-python --without-qt --without-jpeg --without-xv --with-gnu-ld --disable-video --enable-codes=ean --disable-pthread --without-xshm")
        exitOnError("configuring ZBar failed.\nAre you sure the custom ImageMagick version is built?\nTry 'rake magick:buildImageMagick'.")

        puts "#### Make...".bold
        system("#{exec} && make")
        exitOnError("making ZBar failed")

        puts "#### Make install...".bold
        system("#{exec} && make install")
        exitOnError("installing ZBar failed")

        puts
        puts
        puts "NOTE: Removing built zbar-libs in favor of global ones. For some reason the global ones are significantly faster and I can't find the issue. At least this is true for 0.8+dfsg-3 vs. 0.10+* as included in Debian/lenny (libzbar0) and Seee."
        system("rm -rf #{bldZBar}/lib")

        puts
        puts "ZBar has been successfully built.".bold
    end

    desc "clean ZBar compilation files"
    task :cleanZBar do
        system("cd #{srcZBar} && make clean && make distclean")
    end

    desc "remove (uninstall) custom ZBar"
    task :removeZBar do
        puts
        puts "Removing custom ZBar".bold
        system("rm -rf #{bldZBar}")
    end

    desc "Get version info if all built/installed ImageMagick/RMagick and what will be used"
    task :version do
        noi = ' || echo "not (properly?) installed"'
        nob = ' || echo "not (properly?) built"'

        puts
        puts "GLOBAL versions:".bold
        puts "ImageMagick:".bold
        puts `convert -version #{noi}`.strip
        puts
        puts "RMagick:".bold
        puts ` /usr/bin/env ruby -r RMagick -e"puts Magick::Version" #{noi}`.strip
        puts
        puts "RMagick uses:".bold
        puts ` /usr/bin/env ruby -r RMagick -e"puts Magick::Magick_version" #{noi}`.strip

        # find path for installed rmagick/zbar
        rmagickrb = Seee::Config.custom_builds[:rmagick_rb]
        zbar = Seee::Config.application_paths[:zbar]
        puts
        puts
        puts "CUSTOM versions:".bold
        puts "ImageMagick:".bold
        puts `#{bldImgMagick}/bin/convert -version #{nob}`.strip
        puts
        puts "RMagick:".bold
        puts ` /usr/bin/env ruby -r "#{rmagickrb}" -e"puts Magick::Version" #{nob}`.strip
        puts
        puts "RMagick uses:".bold
        puts ` /usr/bin/env ruby -r "#{rmagickrb}" -e"puts Magick::Magick_version" #{nob}`.strip
        puts
        puts "ZBarImg reports:".bold
        puts `#{zbar} --version #{nob}`.strip
        puts "Note: ZBarImg is always custom built, therefore there is no global version. If no ImageMagick version is reported, this likely means it will use the shared libraries in /usr."
    end
end
