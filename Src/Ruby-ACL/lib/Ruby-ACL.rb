$:.unshift("./lib")
require 'ACL_Object'
require 'Principal'
require 'individual'
require 'group'
require 'privilege'
require 'resource_object'
require 'ace'
require 'main'
require 'date'
require 'ace_rule'
require 'rubyacl_exception'

class RubyACL
  
  # common access methods
  attr_reader :name
  attr_reader :col_path
  
  def initialize(name, connector, colpath = "/db/acl/", src_files_path = "./src_files/", report = true) #TODO report
    
    if(name == "")
      raise RubyACLException.new(self.class.name, __method__, "Name is empty", 0), caller
    end
    @name = name
    @connector = connector
    if(colpath[-1] != "/")
      colpath += "/"
    end
    @col_path = colpath
    @src_files_path = src_files_path
    @report = report
    @prin = Principal.new(@connector, @col_path)
    @indi = Individual.new(@connector, @col_path)
    @group = Group.new(@connector, @col_path)
    @priv = Privilege.new(@connector, @col_path)
    @res_obj = ResourceObject.new(@connector, @col_path)
    @ace = Ace.new(@connector, @col_path)
    create_acl_in_db()
    setname(name)
  rescue => e
    raise e
  end
  
  private   # private methods follow
  
  def create_acl_in_db()
    if(!@connector.existscollection?(@col_path))
      #puts "Collection doesn't exist. Creating collection."
      @connector.createcollection(@col_path)
    end
    
    col = @connector.getcollection(@col_path)
    sfs = missing_src_files(col)
    if(sfs != [])   #creates array of documents that dont exist in collection
      missing_files = ""
      sfs.each { |sf| 
        missing_files = missing_files + '"'+sf+'"' 
        if(sf != sfs.last())
          missing_files = missing_files + ", "
        end
      }
      #Creating new source file(s)
      for sfile in sfs
        xmlfile = File.read(@src_files_path + sfile)
        @connector.storeresource(xmlfile, @col_path + sfile)
      end
      col = @connector.getcollection(@col_path)
    end
    
    if(col.name == @col_path && missing_src_files(col) == [])
      puts "ACL collection with source files created." if @report
    else
      raise RubyACLException.new(self.class.name, __method__, "Failed to create ACL in database", 1), caller
    end
  rescue XMLRPC::FaultException => e
    raise e
  rescue => e
    raise e
  end
  
  def missing_src_files(col)   #returns array of files that are not present in acl collection
    files = []
    if(col['acl.xml'] == nil)
      files.push('acl.xml')
    end
    if(col['Principals.xml'] == nil)
      files.push('Principals.xml')
    end
    if(col['Privileges.xml'] == nil)
      files.push('Privileges.xml')
    end
    if(col['ResourceObjects.xml'] == nil)
      files.push('ResourceObjects.xml')
    end
    return files
  end
  
  def parent(adr)
    if(adr[-1] == "/")    #if last is "/" then delete it
      adr = adr[0..-2]
    end
    pos = adr.rindex("/")
    adr = adr[0..pos]
    return adr
  end
  
  #finds membership parrent and returns in sorted array by level, 
  #Root is first leaf is last.
  #e.g. dog's parrent is mammal.
  def find_parent(id, doc)   
    query = "#{doc}//node()[@id=\"#{id}\"]/membership/*/string(@idref)"
    ids = []
    handle = @connector.execute_query(query)
    hits = @connector.get_hits(handle)
    hits.times {
      |i|
      id_ref = @connector.retrieve(handle, i)
      if(id_ref=="")
        next      #for unknown reason eXist returns 1 empty hit even any exists therefore unite is skipped (e.g. //node()[@id="all"]/membership/*/string(@idref)
      end
      ids = find_parent(id_ref, doc) | ids | [id_ref]    #unite arrays
    }
    return ids
  rescue => e
    raise e
  end
  
  #finds membership parrent, e.g. dog's parrent is mammal
  def find_res_ob_parent(res_ob_type, res_ob_adrs)   
    ids = Array.new
    while(res_ob_adrs.rindex("/") != 0)
      res_ob_adrs = parent(res_ob_adrs)
      if(res_ob_adrs[-1] == "/")    #if last is "/" then delete it
        res_ob_adrs = res_ob_adrs[0..-2]
      end
      #puts res_ob_adrs
      ids.push(@res_obj.find_res_ob(res_ob_type, res_ob_adrs))      
    end    
    ids.compact!
    return ids
  rescue => e
    raise e
  end
  
  def decide(res)
    if(res == "allow")
      return true
    elsif(res == "deny")
      return false
    end
  end
  
  def compare(final_ace, temp_ace)   #returns ace that is 
    #TODO compare
    if(final_ace == nil)
      return temp_ace
    end
    
    if(@prin.eq(temp_ace, final_ace) && final_ace.acc_type == "deny")
      if(@priv.ge(temp_ace, final_ace, @privs) && @res_obj.ge(temp_ace, final_ace, @res_obs))
        final_ace = temp_ace
      end
    end
    
    if(@prin.ne(temp_ace, final_ace))
      if(@priv.ge(temp_ace, final_ace, @privs) && @res_obj.ge(temp_ace, final_ace, @privs))
        final_ace = temp_ace
      end
    end
    return final_ace
  rescue => e
    raise e
  end
  
  def prepare_query(prin, privs, res_obs)
    query = <<END
for $ace in #{@ace.doc}//Ace
where (
END
    
    query += "($ace/Principal/@idref=\"#{prin}\")"
    
    query += " and ("
    for priv in privs
      query += "$ace/Privilege/@idref=\"#{priv}\""
      if(priv != privs.last)
        query+=" or "
      else
        query+=") "
      end
    end
    
    query += " and ("
    for res_ob in res_obs
      query += "$ace/ResourceObject/@idref=\"#{res_ob}\""
      if(res_ob != res_obs.last)
        query+=" or "
      else
        query+=") "
      end
    end
    query+=")"
    query += "return $ace/string(@id)"
    return query 
  rescue => e
    raise e
  end
  
  def is_owner?(prin_name, res_ob_id)
    query = "#{@res_obj.doc}//ResourceObject[@id=\"#{res_ob_id}\"]/owner/string(@idref)"
    #puts "query #{query}"
    handle = @connector.execute_query(query)
    owner = @connector.retrieve(handle, 0)   #retrieve owner id of res_ob
    if(prin_name == owner)
      return true
    else 
      return false
    end
  rescue => e
    raise e
  end
  
  protected

  public              # follow public methods

  def setname(new_name)
    query = "update value doc(\"#{@col_path}acl.xml\")/acl/@aclname with \"#{new_name}\""
    @connector.execute_query(query)
    query = "doc(\"#{@col_path}acl.xml\")/acl/string(@aclname)"
    handle = @connector.execute_query(query)
    if(new_name != @connector.retrieve(handle, 0))
      raise RubyACLException.new(self.class.name, __method__, "Failed to set new name", 2), caller
    end
  rescue XMLRPC::FaultException => e
    raise e
  rescue => e
    raise e
  end
  
  def to_s  #TODO
    puts "Name = #{@name} \n\n"
    col = @connector.getcollection(@col_path)
    doc = col['acl.xml']
    doc.content
  rescue => e
    raise e
  end
  
  def save(path, date = false)
    col = @connector.getcollection(@col_path)    
    docs = col.docs()
    if(date)
      path = path + Date.today.to_s + "/"
    end
    if(!File.exists?(path))
      Dir.mkdir(path)
    end
    docs.each{|doc| 
      document = col[doc] 
      #doc = doc + "_BU"
      filename = path + doc
      f = File.new(filename, 'w')
      f.puts(document.content)
      f.close
    }
  rescue => e
    raise e
  end
  
  def RubyACL.load(connector, colpath = "/db/acl/", src_files_path)
    xmlfile = File.read(src_files_path+"acl.xml")
    startindex = xmlfile.index('"', xmlfile.index("aclname="))
    endindex = xmlfile.index('"', startindex+1)
    name = xmlfile[startindex+1..endindex-1]
    newacl = RubyACL.new(name, connector, colpath, src_files_path)
    return newacl
  rescue => e
    raise e
  end
  
  def check(prin_name, priv_name, res_ob_type, res_ob_adrs)
    res_ob_id = @res_obj.find_res_ob(res_ob_type, res_ob_adrs)
    if(is_owner?(prin_name, res_ob_id))
      #puts "is owner"
      return true   #access allowed - owner can do everything
    end
    
    prins = find_parent(prin_name, @prin.doc) + [prin_name]    #creates the set of principals {wanted principal and all groups wanted principal is member of}
    @privs = find_parent(priv_name, @priv.doc) + [priv_name]   #creates the set of privileges {wanted privilege and all privileges wanted privilege is member of}
    @res_obs = [@res_obj.find_res_ob(res_ob_type, res_ob_adrs)] + find_res_ob_parent(res_ob_type, res_ob_adrs)
    
    final_ace = nil
    for prin in prins
      query = prepare_query(prin, @privs, @res_obs)
      handle = @connector.execute_query(query)
      hits = @connector.get_hits(handle)
      if(hits > 0)    
        temp_id = @connector.retrieve(handle, 0)   #retrieve id of first Ace
        temp_ace = AceRule.new(temp_id, @ace, @connector)
        if(hits == 1)
          final_ace = compare(final_ace, temp_ace)
        else    #there are more rules
          hits.times { |i|
            temp_id = @connector.retrieve(handle, i)   #retrieve id of next Ace
            temp_ace.reload!(temp_id)
            final_ace = compare(final_ace, temp_ace)
          }
        end
      end
    end
    
    if(final_ace == nil)  #Rule doesnt exist = access denied
      puts "Required rule (#{prin_name}, #{priv_name}, #{res_ob_type}, #{res_ob_adrs}) does not exist. Access denied."
      return false
    else
      return decide(final_ace.acc_type)
    end
  rescue => e
    raise e
    #puts e.backtrace.join("\n")
    #raise RubyACLException.new(self.class.name, __method__, "Failed to check ACE", 3), caller
  end
  
  def show_permissions_for(prin_name)
    #TODO
  rescue => e
    raise e
  end
  
  def create_ace(prin_name, acc_type, priv_name, res_ob_type, res_ob_adrs, grand_2_children = false)
    #TODO grand_2_children = false, dont forget that /neco/necojinyho doesnt inherit to children
    res_ob_id = @res_obj.find_res_ob(res_ob_type, res_ob_adrs)
    if(res_ob_id == nil)
      res_ob_id = @res_obj.create_new(res_ob_type, res_ob_adrs, prin_name)
    end
    @ace.create_new(prin_name, acc_type, priv_name, res_ob_id)
  rescue => e
    raise e
  end
  
  def create_principal(name, groups = ["ALL"])
    @indi.create_new(name, groups)
  rescue => e
    raise e
  end
  
  def create_group(name, member_of = ["ALL"], members = ["ALL"])    # members can be groups or individuals; check if it the name already exist. or if groups and members exist at all
    @group.create_new(name, member_of, members)   
  rescue => e
    raise e
  end
  
  def create_privilege(name, member_of = ["ALL_PRIVILEGES"])
    @priv.create_new(name, member_of)
  rescue => e
    raise e
  end
  
  def create_resource_object(type, address, owner)
    #puts "type #{type} add #{address}"
    id = @res_obj.create_new(type, address, owner)
    return id
  rescue => e
    raise e
  end
  
  def change_owner(type, address, new_owner)
    @res_obj.change_owner(type, address, new_owner)
  rescue => e
    raise e
  end
  
  def add_membership_principal(name, groups, existance = false) #adds principal into group(s); if you know prin exists set true for prin_exists
    @prin.add_membership(name, groups, existance)
  rescue => e
    raise e
  end
  
  def add_membership_privilege (name, groups, existance = false) #adds privilege into group(s); if you know prin exists set true for prin_exists
    @priv.add_membership(name, groups, existance)
  rescue => e
    raise e
  end
  
  def del_membership_principal(prin_name, groups) #deletes prin_name from group(s)
    @prin.del_membership(prin_name, groups)
  rescue => e
    raise e
  end
  
  def del_membership_privilege(priv_name, groups) #deletes prin_name from group(s)
    @priv.del_membership(priv_name, groups)
  rescue => e
    raise e
  end
  
  def delete_principal(name)
    @prin.delete(name)
  rescue => e
    raise e
  end
  
  def delete_privilege(name)
    @priv.delete(name)
  rescue => e
    raise e
  end
  
  def delete_res_object(type, address)
    res_ob_id = @res_obj.find_res_ob(type, address)
    @res_obj.delete(res_ob_id)
    return res_ob_id
  rescue => e
    raise e
  end
  
  def delete_res_object_by_id(id)
    @res_obj.delete(id)
  rescue => e
    raise e
  end
  
  def delete_ace(ace_id)
    @ace.delete(ace_id)
  rescue => e
    raise e
  end

  
end

#$:.unshift("C:/Users/sirljan/Documents/NetBeansProjects/eXistAPI/lib")
#require "eXistAPI"
#
#db = ExistAPI.new("http://localhost:8080/exist/xmlrpc", "admin", "admin")
#puts "Deleting old ACL from db for testing purposes."
#db.remove_collection("/db/acl/")
#puts 'Creating new acl'
#mojeacl = RubyACL.new("prvniacl", db)
#
#puts "Creating new principal"
#mojeacl.create_principal("labut")
#
#puts "Creating new group"
#mojeacl.create_group('labutiHejno')
#
#puts "Adding membership"
#mojeacl.add_membership_principal('Developers', ['Users'])
#
#puts "Creating privilege"
#mojeacl.create_privilege('KUTALET')
#puts "Creating privilege"
#mojeacl.create_privilege('STAT')
#puts "Adding membership to privilege"
#mojeacl.add_membership_privilege('STAT', ["KUTALET"])
#puts "Deleting privilege"
#mojeacl.del_membership_privilege('STAT', ["KUTALET"])


##mojeacl = RubyACL.load("pokus.xml", db, "/db/acl/")
#
#puts "to_s. JESTLI TO PORAD NEFUNGUJE, TAK TO KOUKEJ DODELAT!!!"
#mojeacl.to_s

#groups = ['Administrators', 'Users', 'Developers', 'Houbari']

#puts "Adding membership"
#mojeacl.add_membership('labutiHejno', ['Users'])

##mojeacl.create_principal("ara")
#mojeacl.add_membership("labut", groups)
#puts "Deleting membership"
#mojeacl.del_membership('labut',['Users'])
#puts "Deleting membership"
#mojeacl.del_membership('Developers',['Administrators'])
#puts "Deleting individual"
#mojeacl.del_prin('Klubicko')
#puts "Deleting group"
#mojeacl.del_prin('Kosik')


#puts "Deleting parent privilege"
#mojeacl.del_priv("STAT")
#puts "Adding ACE"
#mojeacl.add_ace("Houby", "allow", "RUST", "a963")
#puts "Deleting ACE"
#mojeacl.del_ace("a987")
#puts "Checking ACE "+'("Houby", "SELECT", "a963")'
#if(mojeacl.check("Houby", "SELECT", "a963"))
#  puts "Access was allowed"
#else
#  puts "Access was denied"
#end
#puts "Checking ACE - group " + '("sirljan", "SELECT", "a852")'
#if(mojeacl.check("sirljan", "SELECT", "a852"))
#  puts "Access was allowed"
#else
#  puts "Access was denied"
#end
#puts "Saving acl from db to local file."
#mojeacl.save("./backup/")