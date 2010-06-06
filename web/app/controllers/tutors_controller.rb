class TutorsController < ApplicationController
  before_filter :load_course

  def load_course
    if not params[:course_id].nil?
          @course = Course.find(params[:course_id])
    end
  end
  # GET /tutors
  # GET /tutors.xml
  def index
    @tutors = @course.tutors.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @tutors }
    end
  end

  # GET /tutors/1
  # GET /tutors/1.xml
  def show
    @tutor = Tutor.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tutor }
    end
  end

  # GET /tutors/new
  # GET /tutors/new.xml
  def new
    @tutor = @course.tutors.build

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @tutor }
    end
  end

  # GET /tutors/1/edit
  def edit
    @tutor = Tutor.find(params[:id])
    @course = Course.find(@tutor.course_id)
  end

  # POST /tutors
  # POST /tutors.xml
  def create
    @tutor = @course.tutors.build(params[:tutor])
    existingTutors = @course.tutors.map { |x| x.abbr_name }
    par = params[:tutor]['abbr_name'].split(',').map{ |x| x.strip }
    failure = nil
    par.uniq.each do |p|
      next if existingTutors.include? p
      t = @course.tutors.build({'abbr_name'=>p})
      if not t.save
        failure = true
      end
    end
    respond_to do |format|
      if failure.nil?
        flash[:notice] = 'Tutor was successfully created.'
        format.html { redirect_to(@course) }
        format.xml  { render :xml => @tutor, :status => :created, :location => @course }
     else
        format.html { render :action => "new" }
        format.xml  { render :xml => @tutor.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /tutors/1
  # PUT /tutors/1.xml
  def update
    @tutor = @course.tutors.find(params[:id])

    respond_to do |format|
      if @tutor.update_attributes(params[:tutor])
        flash[:notice] = 'Tutor was successfully updated.'
        format.html { redirect_to(@tutor) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tutor.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /tutors/1
  # DELETE /tutors/1.xml
  def destroy
    @tutor = @course.tutors.find(params[:id])
    @tutor.destroy

    respond_to do |format|
      format.html { redirect_to(@course) }
      format.xml  { head :ok }
    end
  end
end
