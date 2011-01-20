class SemestersController < ApplicationController
  # GET /semesters
  # GET /semesters.xml
  def index
    @semesters = Semester.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @semesters }
    end
  end

  # GET /semesters/1
  # GET /semesters/1.xml
  def show
    @semester = Semester.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @semester }
    end
  end

  # GET /semesters/new
  # GET /semesters/new.xml
  def new
    @semester = Semester.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @semester }
    end
  end

  # GET /semesters/1/edit
  def edit
    @semester = Semester.find(params[:id])
  end

  # POST /semesters
  # POST /semesters.xml
  def create
    @semester = Semester.new(params[:semester])

    respond_to do |format|
      if @semester.save
        flash[:notice] = 'Semester was successfully created.'
        format.html { redirect_to(semesters_url) }
        format.xml  { render :xml => @semester, :status => :created, :location => @semester }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @semester.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /semesters/1
  # PUT /semesters/1.xml
  def update
    @semester = Semester.find(params[:id])

    respond_to do |format|
      if @semester.update_attributes(params[:semester])
        flash[:notice] = 'Semester was successfully updated.'
        format.html { redirect_to(semesters_url) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @semester.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /semesters/1
  # DELETE /semesters/1.xml
  def destroy
    @semester = Semester.find(params[:id])
    @semester.destroy unless @semester.critical?

    respond_to do |format|
      flash[:error] = 'Semester was critical and has therefore not been destroyed.' if @semester.critical?
      format.html { redirect_to(semesters_url) }
      format.xml  { head :ok }
    end
  end
end
