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

    respond_to do |format|
      flash[:error] = 'Prof was critical and has therefore not been destroyed.' if @prof.critical?
      format.html { redirect_to(profs_url) }
      format.xml  { head :ok }
    end
  end
end
