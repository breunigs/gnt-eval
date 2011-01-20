# -*- coding: utf-8 -*-

require 'digest/md5'
require 'ftools'

class CoursesController < ApplicationController
  include FunkyTeXBits

  # GET /courses
  # GET /courses.xml
  def index
    @courses = Course.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @courses }
    end
  end

  # GET /courses/1
  # GET /courses/1.xml
  def show
    @course = Course.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @course }
    end
  end

  # GET /courses/new
  # GET /courses/new.xml
  def new
    @course = Course.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @course }
    end
  end

  # GET /courses/1/edit
  def edit
    @course = Course.find(params[:id])
  end

  # GET /courses/1/preview
  def preview
    @course = Course.find(params[:id])
    @failed, @exitcodes, @error, @base64 = texpreview(@course.summary)

    respond_to do |format|
      format.html # preview.html.erb
    end
  end

  # POST /courses
  # POST /courses.xml
  def create
    @course = Course.new(params[:course])

    respond_to do |format|
      if @course.save
        flash[:notice] = 'Course was successfully created.'
        format.html { redirect_to(@course) }
        format.xml  { render :xml => @course, :status => :created, :location => @course }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @course.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /courses/1
  # PUT /courses/1.xml
  def update
    @course = Course.find(params[:id])

    respond_to do |format|
      # FIXME don't change form and language if @course.critical?
      if @course.update_attributes(params[:course])
        flash[:notice] = 'Course was successfully updated.'
        format.html { redirect_to(@course) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @course.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /courses/1
  # DELETE /courses/1.xml
  def destroy
    @course = Course.find(params[:id])
    unless @course.critical?
      begin
        @course.course_profs.each { |cp| cp.destroy }
        @course.tutors.each { |t| t.destroy }
      end
      @course.destroy
    end

    respond_to do |format|
      flash[:error] = 'Course was critical and has therefore not been destroyed.' if @course.critical?
      format.html { redirect_to(courses_url) }
      format.xml  { head :ok }
    end
  end

  # DELETE /courses/drop_prof?course=1&prof=1
  def drop_prof
    @course = Course.find(params[:id])
    unless @course.critical?
      @prof = Prof.find(params[:prof_id])
      @course.profs.delete(@prof)
    end

    respond_to do |format|
      flash[:error] = "Course was critical and therefore prof #{@prof.fullname} has been kept." if @course.critical?
      format.html { redirect_to(@course) }
      format.xml { head :ok }
    end
  end

  def add_prof
    @course = Course.find(params[:id])
    @prof = Prof.find(params[:courses][:profs])
    @course.profs << @prof

    respond_to do |format|
      format.html { redirect_to(@course) }
      format.xml { head :ok }
    end
  end
end

