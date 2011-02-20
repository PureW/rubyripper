#!/usr/bin/env ruby
#    Rubyripper - A secure ripper for Linux/BSD/OSX
#    Copyright (C) 2007 - 2010 Bouke Woudstra (boukewoudstra@gmail.com)
#
#    This file is part of Rubyripper. Rubyripper is free software: you can 
#    redistribute it and/or modify it under the terms of the GNU General
#    Public License as published by the Free Software Foundation, either 
#    version 3 of the License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>

require 'spec_helper'

describe GetFreedbRecord do

  before(:all) do
    @disc = "7F087C0A 10 150 13359 36689 53647 68322 81247 87332 \
106882 122368 124230 2174"
    @query_disc = "/~cddb/cddb.cgi?cmd=cddb+query+7F087C0A+10+150+13359+\
36689+53647+68322+81247+87332+106882+122368+124230+2174&hello=Joe+\
fakestation+rubyripper+test&proto=6"
    @file = 'A fake freedb record file'
  end

  let(:prefs) {double('Preferences').as_null_object}
  let(:http) {double('CgiHttpHandler').as_null_object}
  let(:getFreedb) {GetFreedbRecord.new(prefs, http)}

  before(:each) do
     prefs.stub(:get).with('hostname').and_return 'fakestation'
     prefs.stub(:get).with('username').and_return 'Joe'
     prefs.stub(:get).with('firstHit').and_return false
     prefs.stub(:get).with('debug').and_return false
     http.stub(:path).and_return "/~cddb/cddb.cgi"
     http.stub(:config).exactly(1).times
  end

  it "should not crash if there are no choices but the caller still chooses" do
    getFreedb.choose(0)
    getFreedb.status.should == 'noChoices'
    getFreedb.freedbRecord.should == nil
    getFreedb.category.should == nil
    getFreedb.finalDiscId == nil
  end

  context "After firing a query for a disc to the freedb server" do
    it "should handle the response in case no disc is reported" do
      query = '202 No match found'
      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'noMatches'
      getFreedb.freedbRecord.should == nil
      getFreedb.choices.should == nil
      getFreedb.category.should == nil
      getFreedb.finalDiscId == nil
    end

    it "should handle the error message when the database is corrupt" do
      query = '403 Database entry is corrupt'
      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'databaseCorrupt'
      getFreedb.freedbRecord.should == nil
      getFreedb.choices.should == nil
      getFreedb.category.should == nil
      getFreedb.finalDiscId == nil
    end

    it "should handle an unknown reply message" do
      query = '666 The number of the beast'
      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'unknownReturnCode: 666'
      getFreedb.freedbRecord.should == nil
      getFreedb.choices.should == nil
      getFreedb.category.should == nil
      getFreedb.finalDiscId == nil
    end
    
    it "should handle the response in case 1 record is reported" do
      query = '200 blues 7F087C0A Some random artist / Some random album'
      request = "/~cddb/cddb.cgi?cmd=cddb+read+blues+7F087C0A&hello=\
Joe+fakestation+rubyripper+test&proto=6"
      read = "210 metal 7F087C01\n" + @file + "\n."
      
      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      http.stub(:get).with(request).exactly(1).times.and_return read
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'ok'
      getFreedb.freedbRecord.should == @file
      getFreedb.choices.should == nil
      getFreedb.category.should == 'metal'
      getFreedb.finalDiscId == '7F087C01'
    end
  end
    
  context "when multiple records are reported" do
    it "should take the first when firstHit preference is true" do
      prefs.stub(:get).with('firstHit').and_return true
      choices = "blues 7F087C0A Artist A / Album A\nrock 7F087C0B Artist B / Album \
B\n\jazz 7F087C0C Artist C / Album C\n\country 7F087C0D Artist D / Album D\n."
      query = "211 code close matches found\n#{choices}"
      request = "/~cddb/cddb.cgi?cmd=cddb+read+blues+7F087C0A&hello=\
Joe+fakestation+rubyripper+test&proto=6"
      read = "210 metal 7F087C01\n" + @file + "\n."

      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      http.stub(:get).with(request).exactly(1).times.and_return read
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'ok'
      getFreedb.freedbRecord.should == @file
      getFreedb.choices.should == choices[0..-3].split("\n")
      getFreedb.choices.length.should == 4
      getFreedb.category.should == 'metal'
      getFreedb.finalDiscId == '7F087C01'
    end
      
    it "should allow choosing the first disc" do
      choices = "blues 7F087C0A Artist A / Album A\nrock 7F087C0B Artist B / Album \
B\n\jazz 7F087C0C Artist C / Album C\n\country 7F087C0D Artist D / Album D\n."
      query = "211 code close matches found\n#{choices}"
      request = "/~cddb/cddb.cgi?cmd=cddb+read+blues+7F087C0A&hello=\
Joe+fakestation+rubyripper+test&proto=6"
      read = "210 metal 7F087C01\n" + @file + "\n."

      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      http.stub(:get).with(request).exactly(1).times.and_return read
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'multipleRecords'
      getFreedb.freedbRecord.should == nil
      getFreedb.choices.should == choices[0..-3].split("\n")
      getFreedb.choices.length.should == 4

      # choose the first disc
      getFreedb.choose(0)
      getFreedb.status.should == 'ok'
      getFreedb.freedbRecord.should == @file
      getFreedb.category.should == 'metal'
      getFreedb.finalDiscId == '7F087C01'
    end
      
    it "should allow choosing the second disc" do
      choices = "blues 7F087C0A Artist A / Album A\nrock 7F087C0B Artist B / Album \
B\n\jazz 7F087C0C Artist C / Album C\n\country 7F087C0D Artist D / Album D\n."
      query = "211 code close matches found\n#{choices}"
      request = "/~cddb/cddb.cgi?cmd=cddb+read+rock+7F087C0B&hello=\
Joe+fakestation+rubyripper+test&proto=6"
      read = "210 metal 7F087C01\n" + @file + "\n."

      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      http.stub(:get).with(request).exactly(1).times.and_return read
      getFreedb.handleConnection(@disc)

      # choose the second disc
      getFreedb.choose(1)
      getFreedb.status.should == 'ok'
      getFreedb.freedbRecord.should == @file
      getFreedb.category.should == 'metal'
      getFreedb.finalDiscId == '7F087C01'
    end
      
    it "should allow choosing an invalid choice without crashing" do
      choices = "blues 7F087C0A Artist A / Album A\nrock 7F087C0B Artist B / Album \
B\n\jazz 7F087C0C Artist C / Album C\n\country 7F087C0D Artist D / Album D\n."
      query = "211 code close matches found\n#{choices}"

      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      getFreedb.handleConnection(@disc)
      getFreedb.status.should == 'multipleRecords'

      # choose an unknown
      getFreedb.choose(4)
      getFreedb.status.should == 'choiceNotValid: 4'
      getFreedb.freedbRecord.should == nil
      getFreedb.category.should == nil
      getFreedb.finalDiscId == nil
    end
  end

  context "When requesting a specific disc and an error is returned" do
    it "should handle the response when the disc is not found" do
      query = '200 blues 7F087C0A Some random artist / Some random album'
      request = "/~cddb/cddb.cgi?cmd=cddb+read+blues+7F087C0A&hello=\
Joe+fakestation+rubyripper+test&proto=6"
      read = '401 Cddb entry not found'

      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      http.stub(:get).with(request).exactly(1).times.and_return read
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'cddbEntryNotFound'
      getFreedb.freedbRecord.should == nil
    end

    it "should handle an unknown response code" do
      query = '200 blues 7F087C0A Some random artist / Some random album'
      request = "/~cddb/cddb.cgi?cmd=cddb+read+blues+7F087C0A&hello=\
Joe+fakestation+rubyripper+test&proto=6"
      read = '666 The number of the beast'

      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      http.stub(:get).with(request).exactly(1).times.and_return read
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'unknownReturnCode: 666'
      getFreedb.freedbRecord.should == nil
    end

    it "should handle a server (403) error response on the server" do
      query = '200 blues 7F087C0A Some random artist / Some random album'
      request = "/~cddb/cddb.cgi?cmd=cddb+read+blues+7F087C0A&hello=\
Joe+fakestation+rubyripper+test&proto=6"
      read = '402 There is a temporary server error'

      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      http.stub(:get).with(request).exactly(1).times.and_return read
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'serverError'
      getFreedb.freedbRecord.should == nil
    end

    it "should handle a database (404) error response on the server" do
      query = '200 blues 7F087C0A Some random artist / Some random album'
      request = "/~cddb/cddb.cgi?cmd=cddb+read+blues+7F087C0A&hello=\
Joe+fakestation+rubyripper+test&proto=6"
      read = '403 Database inconsistency error'

      http.stub(:get).with(@query_disc).exactly(1).times.and_return query
      http.stub(:get).with(request).exactly(1).times.and_return read
      getFreedb.handleConnection(@disc)

      getFreedb.status.should == 'databaseCorrupt'
      getFreedb.freedbRecord.should == nil
    end
  end
end