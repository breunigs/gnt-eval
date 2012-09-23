// From http://jqueryui.com/demos/autocomplete/#combobox
//
// With some modifications

$.widget( "ui.combobox", {
  _create: function() {
    var self = this;
    var select = this.element.hide(),
      selected = select.children( ":selected" ),
      value = selected.val() ? selected.text() : "";
    var input = $( "<input />" )
      .insertAfter(select)
      .attr("placeholder", "Search or select…")
      .val( value )
      .autocomplete({
        delay: 50,
        autoFocus: true,
        minLength: 0,
        source: function(request, response) {
          var q = request.term.trim().split(/[;,\s]+/g);
          var highlight = $.map(q, function(v, i) {
            return $.ui.autocomplete.escapeRegex(v);
          }).join("|");
          // convert search terms to regex
          var q = $.map(q, function(v, i) {
            return new RegExp($.ui.autocomplete.escapeRegex(v), "i" );
          });


          response(select.children("option").map(function() {
            var text = $( this ).text();
            var ok = true;
            $.each(q, function(i, qq) { if(!qq.test(text)) ok = false; });

            if (this.value && (!request.term || ok))
              return {
                label: text.replace(
                  new RegExp(
                    "(?![^&;]+;)(?!<[^<>]*)(" +
                    highlight +
                    ")(?![^<>]*>)(?![^&;]+;)", "gi"),
                  "<strong>$1</strong>"),
                value: text,
                option: this
              };
          }) );
        },
        select: function( event, ui ) {
          ui.item.option.selected = true;
          self._trigger( "selected", event, {
            item: ui.item.option
          });
        },
        change: function(event, ui) {
          if ( !ui.item ) {
            var matcher = new RegExp( "^" + $.ui.autocomplete.escapeRegex( $(this).val() ) + "$", "i" ),
            valid = false;
            select.children( "option" ).each(function() {
              if ( this.value.match( matcher ) ) {
                this.selected = valid = true;
                return false;
              }
            });
            if ( !valid ) {
              // remove invalid value, as it didn't match anything
              $( this ).val( "" );
              select.val( "" );
              return false;
            }
          }
        }
      })
      .focus(function(){
          input.select();
          // Shows complete list when clicking the text box. Delay
          // execution to prevent lag and execute it in a bg thread.
          setTimeout(function() {input.autocomplete("search", "")}, 50);
        })
      .addClass("ui-widget ui-widget-content ui-corner-left");

    input.data( "autocomplete" )._renderItem = function( ul, item ) {
      return $( "<li></li>" )
        .data( "item.autocomplete", item )
        .append( "<a>" + item.label + "</a>" )
        .appendTo( ul );
    };
    // type=button is required to prevent it from submitting the form
    // when clicked.
    $( "<button type=\"button\"> </button>" )
    .attr( "tabIndex", -1 )
    .attr( "title", "Show All Items" )
    .insertAfter( input )
    .button({
      icons: {
        primary: "ui-icon-triangle-1-s"
      },
      text: false
    })
    .removeClass( "ui-corner-all" )
    .addClass( "ui-corner-right ui-button-icon" )
    .click(function() {
      // close if already visible
      if (input.autocomplete("widget").is(":visible")) {
        input.autocomplete("close");
        return;
      }
      // pass empty string as value to search for, displaying all results
      input.autocomplete("search", "");
      input.focus();
    });
  }
});

$(document).ready(function() {
  $("select.combobox").combobox();
});
