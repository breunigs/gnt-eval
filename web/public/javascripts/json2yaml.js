/***********************************************************************
 * The fact that all tested JS engines (Gecko, Presto and WebKit) store
 * the properties in-order is abused to generate a proper Ruby-ish YAML.
 **********************************************************************/

function rubyObject(type, data) {
  this.rubyobject = type.replace("!ruby/object:", "");
  for(x in data) {
    this[x] = data[x];
  }
}

constructRubyObject = function constructRubyObject(node) {
  //console.log(node.tag);
  if (node.constructor.id == "scalar")
    return new rubyObject(node.tag, null);
  return new rubyObject(node.tag, this.constructMapping(node, true));
};


jsyaml.addConstructor('!ruby/object:Box', constructRubyObject );
jsyaml.addConstructor('!ruby/object:Question', constructRubyObject );
jsyaml.addConstructor('!ruby/object:Section', constructRubyObject );
jsyaml.addConstructor('!ruby/object:Page', constructRubyObject );
jsyaml.addConstructor('!ruby/object:AbstractForm', constructRubyObject );



/***********************************************************************
 * JSON 2 Rubyish-YAML exporter
 *
 * Based on https://github.com/jeffsu/json2yaml
 * License is MIT
 **********************************************************************/
(function (self) {
  var spacing = "  ";

  function getType(obj) {
    var type = typeof obj;
    if (obj instanceof Array) {
      return 'array';
    } else if (type == 'string') {
      return 'string';
    } else if (type == 'boolean') {
      return 'boolean';
    } else if (type == 'number') {
      return 'number';
    } else if (type == 'undefined' || obj === null) {
      return 'null';
    } else {
      return 'hash';
    }
  }

  function convert(obj, ret) {
    var type = getType(obj);

    switch(type) {
      case 'array':
        convertArray(obj, ret);
        break;
      case 'hash':
        convertHash(obj, ret);
        break;
      case 'string':
        convertString(obj, ret);
        break;
      case 'null':
        ret.push('null');
        break;
      case 'number':
        ret.push(obj.toString());
        break;
      case 'boolean':
        ret.push(obj ? 'true' : 'false');
        break;
    }
  }

  function convertArray(obj, ret) {
    for (var i=0; i<obj.length; i++) {
      var ele = obj[i];
      var recurse = [];
      convert(ele, recurse);

      for (var j=0; j<recurse.length; j++) {
        ret.push((j == 0 ? "- " : spacing) + recurse[j]);
      }
    }
  }

  function convertHash(obj, ret) {
    for (var k in obj) {
      var recurse = [];
      if (obj.hasOwnProperty(k)) {
        var ele = obj[k];
        convert(ele, recurse);
        var type = getType(ele);
        var name = normalizeString(k);
        if (type == 'null') {
          // don’t add, as we can simply emit null or nil values for
          // Rubyish-YAML.
          //console.log("Skipping value " + name + " because it’s null");
        } else if (type == 'string' || type == 'number' || type == 'boolean') {
          name = (name == "rubyobject" ? '!ruby/object:' : name+': ');
          if(recurse[0] == "AbstractForm") name = "--- " + name;
          ret.push(name + recurse[0]);
        } else {
          ret.push(name + ': ');
          for (var i=0; i<recurse.length; i++) {
            ret.push(spacing + recurse[i]);
          }
        }
      }
    }
  }

  function normalizeString(str) {
    // allow Ruby symbols to appear without quotes
    if (str.match(/^:?\w+$/)) {
      return str;
    } else {
      return JSON.stringify(str);
    }
  }

  function convertString(obj, ret) {
    ret.push(normalizeString(obj));
  }

  self.json2yaml = function(obj) {
    if (typeof obj == 'string') {
      obj = JSON.parse(obj);
    }

    var ret = [];
    convert(obj, ret);
    // clean up trailing whitespace
    return ret.join("\n").replace(/\s+\n/g, "\n");
  };

})(this);
