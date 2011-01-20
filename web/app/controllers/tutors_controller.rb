class TutorsController < ApplicationController
  before_filter :load_course

  include FunkyTeXBits

  def load_course
    if not params[:course_id].nil?
          @course = Course.find(params[:course_id])
    end
  end
  # GET /tutors
  # GET /tutors.xml
  def index
    @tutors = Tutor.all.reject { |x| x.course.nil? }
    @tutors.sort! { |x,y| x.abbr_name <=> y.abbr_name }

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

  # GET /tutors/1/preview
  def preview
    @tutor = Tutor.find(params[:id])
    @failed, @exitcodes, @error, @base64 = texpreview(@tutor.comment)

    respond_to do |format|
      format.html # preview.html.erb
    end
  end

  # POST /tutors
  # POST /tutors.xml
  def create
    existingTutors = @course.tutors.map { |x| x.abbr_name }
    par = params[:tutor]['abbr_name'].split(',').map{ |x| x.strip }
    failure = nil
    par.uniq.sort.each do |p|
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
    @tutor.destroy unless @tutor.critical?

    respond_to do |format|
      flash[:error] = 'Tutor was critical and has therefore not been destroyed.' if @tutor.critical?
      format.html { redirect_to(@course) }
      format.xml  { head :ok }
    end
  end
end
