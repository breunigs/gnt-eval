# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130110093720) do

  create_table "c_pics", :force => true do |t|
    t.string   "basename"
    t.integer  "course_prof_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "source"
    t.string   "text"
    t.integer  "step"
  end

  create_table "course_profs", :force => true do |t|
    t.integer "course_id"
    t.integer "prof_id"
  end

  create_table "courses", :force => true do |t|
    t.integer  "term_id"
    t.string   "title"
    t.integer  "students"
    t.integer  "faculty_id"
    t.integer  "old_form_i"
    t.string   "evaluator"
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "summary"
    t.string   "fscontact"
    t.integer  "form_id"
    t.string   "language"
    t.text     "note"
    t.string   "mails_sent"
  end

  create_table "faculties", :force => true do |t|
    t.string   "longname"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "shortname"
  end

  create_table "forms", :force => true do |t|
    t.integer  "term_id"
    t.string   "name"
    t.text     "content"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pics", :force => true do |t|
    t.integer  "tutor_id"
    t.string   "basename"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "source"
    t.string   "text"
    t.integer  "step"
  end

  create_table "profs", :force => true do |t|
    t.string   "firstname"
    t.string   "surname"
    t.string   "email"
    t.integer  "gender"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sessions", :force => true do |t|
    t.string   "ident"
    t.string   "cont"
    t.integer  "viewed_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.string   "ip"
    t.string   "agent"
    t.string   "username"
  end

  create_table "terms", :force => true do |t|
    t.date     "firstday"
    t.date     "lastday"
    t.string   "title"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "critical"
    t.string   "longtitle"
  end

  create_table "tutors", :force => true do |t|
    t.integer  "course_id"
    t.string   "abbr_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comment"
  end

end
