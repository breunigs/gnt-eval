# encoding: utf-8

class ProfsController < ApplicationController
  # GET /profs
  # GET /profs.xml
  def index
    @profs = Prof.find(:all, :order => [:surname, :firstname])

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @profs }
    end
  end

  # GET /profs/1
  # GET /profs/1.xml
  def show
    @prof = Prof.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @prof }
    end
  end

  # GET /profs/new
  # GET /profs/new.xml
  def new
    @prof = Prof.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @prof }
    end
  end

  # GET /profs/1/edit
  def edit
    @prof = Prof.find(params[:id])
  end

  # POST /profs
  # POST /profs.xml
  def create
    @prof = Prof.new(params[:prof])
    kill_caches

    respond_to do |format|
      if @prof.save
        flash[:notice] = 'Prof was successfully created.'
        format.html { redirect_to(profs_url) }
        format.xml  { render :xml => @prof, :status => :created, :location => @prof }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @prof.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /profs/1
  # PUT /profs/1.xml
  def update
    @prof = Prof.find(params[:id])
    kill_caches @prof
    respond_to do |format|
      if @prof.update_attributes(params[:prof])
        flash[:notice] = "Prof '#{@prof.firstname} #{@prof.surname}' was successfully updated."
        format.html { redirect_to(profs_url) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @prof.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /profs/1
  # DELETE /profs/1.xml
  def destroy
    @prof = Prof.find(params[:id])
    @prof.destroy unless @prof.critical?

    kill_caches @prof

    respond_to do |format|
      flash[:error] = 'Prof was critical and has therefore not been destroyed.' if @prof.critical?
      format.html { redirect_to(profs_url) }
      format.xml  { head :ok }
    end
  end

  # Can’t cache index because then apache will serve the cached variant
  # when submitting the new-prof form
  #caches_page :new, :edit
  private
  def kill_caches(prof = nil)
    logger.info "="*50
    logger.info "Expiring prof caches" + (prof ? " for #{prof.surname}" : "")
    expire_page :action => "index"
    expire_page :action => "new"
    expire_page(:action => "edit", :id => prof) if prof

    # the list of profs is shown on both new and show pages, therefore
    # these need to be expired, regardless which prof changed
    expire_page :controller => "courses", :action => "new"
    Course.find(:all).each do |c|
      expire_page :controller => "courses", :action => "edit", :id => c
    end

    # courses#index shows the prof as well
    expire_page :controller => "courses", :action => "index"
  end
end
