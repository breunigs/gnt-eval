namespace :testhelper do
  Scc = Seee::Config.commands

  # print and execute a command
  def cmd(line)
    puts line
    `#{line}`
  end

  desc "helps you create ground truths to test OMR against. Put the sheet into tests/omr-test/1234.yaml and images into tests/omr-test/1234/{images}"
  task :create_ground_truths do
   Dir.chdir("tests") do
      cmd("./create-ground-truths.rb")
      puts
    end
  end

  desc "debugs the sample sheets as if they were scanned so you can see if OMR is working correctly"
  task :debug_samplesheets => 'pdf:samplesheets' do
    Dir.chdir("tmp/sample_sheets") do
      Dir.glob("*.yaml") do |f|
        f = f.gsub(/\.yaml$/, "")
        next unless File.exist?("#{f}.pdf")
        # note that the filename for the yaml file and tif file need to be different. Otherwise the
        # TeX’s-YAML file will be overwritten by the processed-YAML file which contains the pixel
        # coordinates instead of the original TeX ones. This makes re-processing cumbersome, as the
        # sample sheets would have to be re-rendered. A proper way to fix this would be if OMR would
        # store the pixels into different variables. FIXME
        unless File.exist?("dbg_#{f}.tif")
          puts
          puts "Now converting #{f}.pdf to tif"
          cmd("#{Scc[:convert]} -density 300 -monochrome \"#{f}.pdf\" \"dbg_#{f}.tif\"")
        end

        puts
        puts "Now running OMR on dbg_#{f}.tif"
        cmd("../../pest/omr2.rb -t -d -v -s \"#{f}.yaml\" -p . dbg_#{f}.tif")
      end
    end
  end

  desc "test OMR against reference files in tests/omr-test"
  task :test_omr do
    Dir.chdir("tests") do
      cmd("./omr-test.rb")
      puts
    end
  end

  desc "test if ZBar finds all barcodes and correctly aligns the pages"
  task :test_zbar do
    fails = 0
    Dir.chdir("tests/zbar-test") do
      Dir.glob("orig_*.tif") do |f|
        puts
        puts
        f = f.gsub("orig_", "")
        system("#{Scc[:cp]} orig_#{f} test_#{f}")
        system("#{Scc[:chmod]} +w test_#{f}")
        bc = cmd("#{Scc[:zbar]} test_#{f}")
        if $?.exitstatus != 0 || bc.strip != "00000000"
          puts "ERROR:".bold
          puts "Either zbarimg failed or has detected a wrong barcode.".bold
          puts "Detected Barcode: #{bc.strip}".bold
          pp `#{Scc[:zbar]} test_#{f}`
          fails += 1
          next
        end
        iorig = cmd("#{Scc[:identify]} orig_#{f}").split("\n").count
        itest = cmd("#{Scc[:identify]} test_#{f}").split("\n").count
        if itest != iorig
          puts "ERROR".bold
          puts "Processed file has #{itest} pages whereas it should have #{iorig}.".bold
          fails += 1
          next
        end
        cmd("rm test_#{f}")
      end
    end
    puts
    puts
    puts "#{fails} image(s) have failed the test. Please inspect the files." if fails > 0
  end
end
