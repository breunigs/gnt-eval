namespace :testhelper do
  Scc = Seee::Config.commands

  # print and execute a command
  def cmd(line)
    puts line
    system line
  end

  desc "helps you create ground truths to test OMR against. Put the sheet into tests/omr-test/1234.yaml and images into tests/omr-test/1234/{images}"
  task :create_ground_truths do
   Dir.chdir("tests") do
      cmd("./create-ground-truths.rb")
      puts
    end
  end

  desc "debugs the sample sheets as if they were scanned so you can see if OMR is working correctly"
  task :debug_samplesheets, :needs => 'pdf:samplesheets' do
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

  desc "test OMR against reference files in tests/test-images"
  task :test_omr do
    Dir.chdir("tests") do
      cmd("./omr-test.rb")
      puts
    end
  end

  desc "test if ZBar finds all barcodes and correctly alignes the pages"
  task :test_zbar do
    fails = 0
    Dir.chdir("tests/zbar-test") do
      Dir.glob("orig_*.tif") do |f|
        f = f.gsub("orig_", "")
        system("#{Scc[:cp]} orig_#{f} test_#{f}")
        cmd("#{Scc[:zbar]} test_#{f}")
        # if an image exceeds the dissimilarity threshold compare will exit with status 1. If the
        # images are similar enough, it will return 0 and print the peak signal to noise ratio
        # (PSNR) on the command line. For our purposes, the fail/doesn’t fail test should be enough.
        cmd("#{Scc[:compare]} -dissimilarity-threshold 0.05 test_#{f} reference_#{f} diff_#{f}.jpg")
        if $?.exitstatus == 0
          puts "the result and reference file are very similar (less than 5% difference). Deleting temporary files."
          system("rm -f test_#{f} diff_#{f}")
        else
          puts "WARNING: The result and reference file are quite different.".bold
          puts "Please examine the files test_#{f} and reference_#{f}."
          fails += 1
        end
        puts
        puts
      end
    end
    puts "#{fails} image(s) have failed the test. Please inspect the files." if fails > 0
  end
end
