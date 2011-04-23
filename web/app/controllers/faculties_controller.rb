class FacultiesController < ApplicationController
  # GET /faculties
  # GET /faculties.xml
  def index
    @faculties = Faculty.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @faculties }
    end
  end

  # GET /faculties/1
  # GET /faculties/1.xml
  def show
    @faculty = Faculty.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @faculty }
    end
  end

  # GET /faculties/new
  # GET /faculties/new.xml
  def new
    @faculty = Faculty.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @faculty }
    end
  end

  # GET /faculties/1/edit
  def edit
    @faculty = Faculty.find(params[:id])
  end

  # POST /faculties
  # POST /faculties.xml
  def create
    @faculty = Faculty.new(params[:faculty])
    kill_caches @faculty

    respond_to do |format|
      if @faculty.save
        flash[:notice] = 'Faculty was successfully created.'
        format.html { redirect_to(faculties_url) }
        format.xml  { render :xml => @faculty, :status => :created, :location => @faculty }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @faculty.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /faculties/1
  # PUT /faculties/1.xml
  def update
    @faculty = Faculty.find(params[:id])
    kill_caches @faculty

    respond_to do |format|
      if @faculty.update_attributes(params[:faculty])
        flash[:notice] = 'Faculty was successfully updated.'
        format.html { redirect_to(faculties_url) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @faculty.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /faculties/1
  # DELETE /faculties/1.xml
  def destroy
    @faculty = Faculty.find(params[:id])
    @faculty.destroy unless @faculty.critical?
    kill_caches @faculty

    respond_to do |format|
      flash[:error] = 'Faculty was critical and has therefore not been destroyed.' if @faculty.critical?
      format.html { redirect_to(faculties_url) }
      format.xml  { head :ok }
    end
  end

  caches_page :index, :new, :edit
  private
  def kill_caches(faculty = nil)
    puts "="*50
    puts "Expiring faculty caches" + (faculty ? " for #{faculty.longname}" : "")
    expire_page :action => "index"
    expire_page :action => "new"
    expire_page :action => "edit", :id => faculty

    expire_page :controller => "courses", :action => "index"
    # need to expire all edit/new pages, in case a faculty was added
    Course.find(:all).each do |c|
      puts "Expiring courses#new+edit for #{c.title}"
      expire_page :controller => "courses", :action => "edit", :id => c
      expire_page :controller => "courses", :action => "new", :id => c
    end

    return unless faculty
    faculty.courses.each do |c|
      puts "Expiring courses#show for #{c.title}"
      expire_page :controller => "courses", :action => "show", :id => c
    end
  end
end
