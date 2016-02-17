/*
    Originally written in 2011 by Ryan Foster

    04/01/2012 James Melville Changes made throughout to support NPSP HH

    Updated January 2016 by Ryan Foster and relicensed:

    Copyright (c) 2016, Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

(function($) {
  'use strict';

  var pgController;
  var fldPfx;
  var fldPfxNpsp;

  // Set the controller for APEX Remoting methods to handle managed/unmanaged
  // todo: replace this and pgController throughout with Wes Nolte's cleaner code: http://th3silverlining.com/2012/02/26/salesforce-javascript-remoting-and-managed-packages/
  try {
    pgController = npsp.HH_ManageHousehold_EXT;
    fldPfx = 'npo02__';
    fldPfxNpsp = 'npsp__';
  } catch (err) {
    pgController = HH_ManageHousehold_EXT;
    fldPfx = 'npo02__';
    fldPfxNpsp = ''; //set to blank for unmanaged package
  }

  function fldNm(str) {
    return fldPfx + str;
  }

  function fldNmNpsp(str) {
    return fldPfxNpsp + str;
  }

  $(function() {
    //make the contact cards sortable
    $('div.hhMembers').sortable({
      axis: 'x',
      //define a function that fires each time they are re-ordered
      update: function(event, ui) {

        //write the order of the cards to their data attributes
        $('div.hhCard').each(function(i) {
          var card = $(this);
          if (!card.hasClass('hhCard-new'))
            gwManageHH.state.activeContacts[card.attr('id')][fldNm('Household_Naming_Order__c')] = i;
          else
            card.data('contact')[fldNm('Household_Naming_Order__c')] = i;
        });
        //end each

        //and regenerate the household names as appropriate
        gwManageHH.jsonState = JSON.stringify(gwManageHH.state);
        gwManageHH.setInsertContacts();
        gwManageHH.setNaming();
      }
    });


    /* Autocomplete contact search box for adding existing contacts to HH */

    $('#hhSearch-input').autocomplete({
      minLength: 1,
      position: {
        my: "right top",
        at: "right bottom",
        collision: "none"
      },
      source: function(request, response) {
        var searchStr = request.term.toLowerCase();
        pgController.findContacts(searchStr, gwManageHH.jsonState, function(result, event) {
          if (event.type == 'exception') {
            alert(event.message);
          } else {
            if (result != null) {
              response($.map(result, function(item) {
                return {
                  label: item.Name,
                  value: item.Id,
                  contact: item
                };
              }));
            }
          }
        });
      },
      select: function(event, ui) {
        $(this).val(ui.item.label);
        return false;
      }
    });


    $('#hhSearch-input').data('ui-autocomplete')._renderItem = function(ul, item) {
      var address = gwManageHH.addressStringify(item.contact);

      var linode = $('<li class="hhSearch-item"></li>').data("item.autocomplete", item).append('<span class="hhSearch-item-name">' + item.label + '</span><span class="hhSearch-item-address">' + address + '</span>');

      // If the contact is in a household add a visual indicator
      if (item.contact[fldNmNpsp('HHId__c')] != null) {
        linode.find('.hhSearch-item-address').after('<span class="hhSearch-item-hh">' + gwManageHH.lblExistingHH + '</span>');
      }

      // insert add button
      linode.append('<button class="gwPreventUI gwButton hhSearch-item-add">' + gwManageHH.lblAdd + '</button>');
      linode.find('.hhSearch-item-add').button();

      // insert icon
      linode.prepend('<div class="hhCard-icon">Contact</div>');

      return linode.appendTo(ul);
    };

    // setup search item add buttons
    $('.hhSearch-item-add').live('click', gwManageHH.dialogAddMember);

    // setup search input
    $('.gwTitleLabel').val($('.gwTitleLabel').attr('title'));
    $('.gwTitleLabel').live('focusin focusout', function(event) {
      var ht = $(this).attr('title');
      var v = $(this).val();
      if (event.type == 'focusin') {
        if (ht == v) {
          $(this).val('');
        }
      } else if (event.type == 'focusout') {
        if (v == '') {
          $(this).val(ht);
        }
      }

    });

    //Naming form
    $('#hhNaming input[type="checkbox"]').change(gwManageHH.setNaming);
    $('#hhNaming input[type="text"]').not('.gwField-disable').change(gwManageHH.setNaming);

    // Address change scripts
    //Accordions
    $('.hhAddress-change').button();
    $('.hhAddress-change').click(gwManageHH.dialogChangeAddress);


    // Handle the copy address to contacts flag.
    // this uses the useAddress boolean state value to decide whether to copy all values to the
    $('#hhCopyAddressToContacts').change(function() {
      gwManageHH.state.useAddress = $(this).is(':checked');
      gwManageHH.renderMembers();
      if (gwManageHH.jsonState != gwManageHH.originalState) $('.gwNotifications').gwNotify(gwManageHH.lblChangesNotSaved, {
        type: 'info'
      });
    });

    // All Exclude from naming checkbox actions
    // Attaches event handler to all naming exclusion checkboxes on contact cards and writes any changes to the contact object
    $('.hh-name-exclude-input, .hh-formal-exclude-input, .hh-informal-exclude-input').live('change', function(event) {
      var card = $(this).closest('.hhCard');

      /* NPSP uses a multiselect picklist for naming exclusions which is rendered as checkboxes for 3 possible values here
       * the below code takes the checkboxes values populates the picklist text values accordingly */

      //build naming exclusions field
      var namingExclusions = '';
      if (card.find('.hh-name-exclude-input').is(':checked'))
        namingExclusions += 'Name;';
      if (card.find('.hh-formal-exclude-input').is(':checked'))
        namingExclusions += 'Formal_Greeting__c;';
      if (card.find('.hh-informal-exclude-input').is(':checked'))
        namingExclusions += 'Informal_Greeting__c;';

      if (!card.hasClass('hhCard-new')) {
        var cid = card.attr('id');

        gwManageHH.setNameExclusion(cid, namingExclusions);
      } else {
        var contact = card.data('contact');
        contact[fldNm('Naming_Exclusions__c')] = namingExclusions;
        card.data('contact', contact);
        gwManageHH.setInsertContacts();
        gwManageHH.setNaming();
      }
    });

    // Controls
    $('.gwControls-save').click(function() {
      gwManageHH.saveHousehold();
      gwManageHH.renderControls(false);
      return false;
    });


    // Cards
    $('.hhCard').live('mouseenter mouseleave', function(event) {
      if (event.type == 'mouseenter') {
        $(this).find('.hhCard-delete').show();
      }
      if (event.type == 'mouseleave') {
        $(this).find('.hhCard-delete').hide();
      }
    });

    // Add new
    $('.hhAddNew').live('click', function(event) {
      gwManageHH.addNewContact();
      return false;
    });

    //Deletes
    $('.hhCard-delete').live('mouseenter mouseleave click', function(event) {
      if (event.type == 'click') {
        var card = $(this).closest('.hhCard');
        var isNew = card.hasClass('hhCard-new');
        if (!isNew) {
          var cid = card.attr('id');
          var name = gwManageHH.state.activeContacts[cid]['Name'];

          // if the contact being removed is the primary contact,
          // we need to clear out the primary contact field if it is present
          // on the form.
          var ctrl = $('.sfField-npe01__One2OneContact__c');
          if (ctrl != null && ctrl.val() == name) {
            ctrl.val('');
          }

          gwManageHH.removeMember(cid);

        } else {
          card.remove();
          gwManageHH.setInsertContacts();
          gwManageHH.setNaming();
        }
      }

      if (event.type == 'mouseenter') {
        $(this).addClass('ui-state-error');
      }
      if (event.type == 'mouseleave') {
        $(this).removeClass('ui-state-error');
      }

    });

    $('.hhAddNew').button();

    // Render all
    gwManageHH.updateState(gwManageHH.jsonState);

  });



  gwManageHH.cardPrototype = '<div class="hhCard"><div class="hhCard-icon">' + gwManageHH.lblContact + '</div><div class="hhCard-details"><span class="hhCard-details-name"/><span class="hhCard-details-address"/><div class="gwDiscreet">' + gwManageHH.lblExcludeText + '<br/><span class="hh-name-exclude"><input class="gwPreventUI hh-name-exclude-input" type="checkbox"/><label>' + gwManageHH.lblExcludeName + '</label></span><br/><span class="hh-formal-exclude"><input class="gwPreventUI hh-formal-exclude-input" type="checkbox"/><label>' + gwManageHH.lblExcludeFormal + '</label></span><br/><span class="hh-informal-exclude"><input class="gwPreventUI hh-informal-exclude-input" type="checkbox"/><label>' + gwManageHH.lblExcludeInformal + '</label></span></div></div></div>';
  gwManageHH.renderCard = function(contact) {

    var card = $(gwManageHH.cardPrototype);

    // Insert name
    var cLink = $('<a />');
    cLink.attr('href', '/' + contact.Id).attr('target', '_blank').text(contact.Name);
    card.find('.hhCard-details-name').html(cLink);

    // Insert address
    card.find('.hhCard-details-address').html(gwManageHH.addressStringify(contact));

    /* NPSP uses a multiselect picklist for naming exclusions which is rendered as checkboxes for 3 possible values here
     * the below code takes the text values in the picklist and renders the checkboxes accordingly */

    var namingExclusions = contact[fldNm('Naming_Exclusions__c')];

    if (namingExclusions != null && namingExclusions.indexOf('Name') != -1) {
      card.find('.hh-name-exclude').find('input').attr('checked', 'checked');
    } else {
      card.find('.hh-name-exclude').find('input').removeAttr('checked');
    }

    if (namingExclusions != null && namingExclusions.indexOf('Formal_Greeting__c') != -1) {
      card.find('.hh-formal-exclude').find('input').attr('checked', 'checked');
    } else {
      card.find('.hh-formal-exclude').find('input').removeAttr('checked');
    }

    if (namingExclusions != null && namingExclusions.indexOf('Informal_Greeting__c') != -1) {
      card.find('.hh-informal-exclude').find('input').attr('checked', 'checked');
    } else {
      card.find('.hh-informal-exclude').find('input').removeAttr('checked');
    }

    //each time we render a card order it
    contact[fldNm('Household_Naming_Order__c')] = $('div.hhCard').size();

    // Add delete
    var del = $('<button class="gwPreventUI hhCard-delete" />');
    del.button({
      icons: {
        primary: "ui-icon-circle-minus"
      },
      text: false
    });
    del.hide();
    card.append(del);

    // Give card unique ID
    card.attr('id', contact.Id);

    //Hide the card
    card.css('opacity', '0.0');

    // Add card to dom
    $('div.hhMembers').append(card);

    // Blingify it
    card.animate({
      opacity: 1.0
    }, 500);
  }

  gwManageHH.updateCard = function(contact) {

    var card = $('#' + contact.Id);

    var exAddy = card.find('.hhCard-details-address').html();
    var newAddy = gwManageHH.addressStringify(contact);

    if (exAddy != newAddy) {
      card.find('.hhCard-details-address').html(newAddy);
    }

    /* NPSP uses a multiselect picklist for naming exclusions which is rendered as checkboxes for 3 possible values here
     * the below code takes the text values in the picklist and renders the checkboxes accordingly */

    var namingExclusions = contact[fldNm('Naming_Exclusions__c')];

    if (namingExclusions != null && namingExclusions.indexOf('Name') != -1) {
      card.find('.hh-name-exclude').find('input').attr('checked', 'checked');
    } else {
      card.find('.hh-name-exclude').find('input').removeAttr('checked');
    }

    if (namingExclusions != null && namingExclusions.indexOf('Formal_Greeting__c') != -1) {
      card.find('.hh-formal-exclude').find('input').attr('checked', 'checked');
    } else {
      card.find('.hh-formal-exclude').find('input').removeAttr('checked');
    }

    if (namingExclusions != null && namingExclusions.indexOf('Informal_Greeting__c') != -1) {
      card.find('.hh-informal-exclude').find('input').attr('checked', 'checked');
    } else {
      card.find('.hh-informal-exclude').find('input').removeAttr('checked');
    }
  }
  gwManageHH.addNewContact = function() {
    var card = $(gwManageHH.cardPrototype);

    card.addClass('hhCard-new');

    card.find('.hhCard-details-address').remove();
    card.find('.hhCard-details-name').remove();

    var firstN = $('<input class="gwTitleLabel hhCard-new-input" name="FirstName" title="' + gwManageHH.lblContactFirstName + '" type="text" />');
    var lastN = $('<input class="gwTitleLabel hhCard-new-input" name="LastName" title="' + gwManageHH.lblContactLastName + '" type="text" />');

    var err = $('<span class="hhCard-error" />');
    err.text(gwManageHH.lblContactNameRqd);

    var cardD = card.find('.hhCard-details');

    cardD.prepend(err);
    cardD.prepend(lastN);
    cardD.prepend(firstN);
    firstN.val(firstN.attr('title'));
    lastN.val(lastN.attr('title'));

    // Add delete
    var del = $('<button class="gwPreventUI hhCard-delete" />');
    del.button({
      icons: {
        primary: "ui-icon-circle-minus"
      },
      text: false
    });
    del.hide();
    card.append(del);

    var cntct = {
      "FirstName": "",
      "LastName": ""
    };
    cntct[fldNm('Naming_Exclusions__c')] = '';
    //last contact in naming order by default
    cntct[fldNm('Household_Naming_Order__c')] = $('div.hhCard').size();
    card.data('contact', cntct);

    //hide the "no household members" message
    $('.hhMembers-none').addClass('gwHidden');

    firstN.focus(function() {
      var obj = $(this);
      var nm = obj.attr('name');
      if (nm == 'FirstName') obj.removeClass('gwTitleLabel');
    });

    card.find('.hhCard-new-input').change(function() {
      var obj = $(this);
      var hhcard = obj.closest('.hhCard-new');
      var contact = hhcard.data('contact');

      var nm = obj.attr('name');

      contact[nm] = obj.val();
      if (contact.LastName == '' || contact.LastName == gwManageHH.lblContactLastName) {
        hhcard.find('.hhCard-error').text(gwManageHH.lblContactLastNameRqd);
      } else {
        hhcard.find('.hhCard-error').text('');
        hhcard.find('.hhCard-error').text(gwManageHH.lblContactCreatedOnSave);
        gwManageHH.setInsertContacts();
        gwManageHH.setNaming();
      }
      hhcard.data('contact', contact);
    });

    $('div.hhMembers').append(card);
  }

  gwManageHH.updateState = function(state) {
    // First set the state variables
    gwManageHH.state = JSON.parse(state);
    gwManageHH.jsonState = state;

    // Now update the interface
    gwManageHH.renderMembers();

    // Set the address
    gwManageHH.renderAddress();

    // Setup the naming fields
    gwManageHH.renderNaming();

    // Controls
    gwManageHH.renderControls(true);
  }
  gwManageHH.dialogAddMember = function(event) {
    var linode = $(this).closest('.hhSearch-item');
    var contact = linode.data('item.autocomplete').contact;

    if (contact[fldNmNpsp('HHId__c')] != null) {
      var dialog = $('#dialog-addmember');
      dialog.data('contact', contact);

      // Tweak the text of the dialog to show the contact's name
      dialog.find('#dialog-addmember-name').text(contact.Name);

      //merge button labels
      var btns = {};
      btns[gwManageHH.lblAddAndMerge] = function() {
        $(this).dialog("close");
        $(this).fadeOut();
        linode.toggleClass('hhSearch-item-added');
        gwManageHH.addMember(contact.Id, true);
      };
      btns[gwManageHH.lblAddAndRemove] = function() {
        $(this).dialog("close");
        $(this).fadeOut();
        linode.toggleClass('hhSearch-item-added');
        gwManageHH.addMember(contact.Id, false);
      };
      btns[gwManageHH.lblCancel] = function() {
        $(this).dialog("close");
      };
      dialog.dialog({
        buttons: btns
      });
    } else {
      linode.toggleClass('hhSearch-item-added');
      $(this).fadeOut();
      gwManageHH.addMember(contact.Id, false);
    }
  }

  gwManageHH.dialogChangeAddress = function(event) {
    event.preventDefault();

    var state = gwManageHH.state;
    var dialog = $('#dialog-changeaddress');
    var displayAddresses = new Array();

    if (state.viableAddresses != {}) {
      var addrs = new Array();
      // Get viable addresses if there are any and build an array of address strings
      for (var address in state.viableAddresses) {
        addrs.push(state.viableAddresses[address]);
      }

      var adList = $('<ul />');
      $(addrs).each(function() {
        var adItem = $('<li />');
        displayAddresses.push(gwManageHH.addressStringify(this));
        adItem.addClass('hhAddress-list-item').html(gwManageHH.addressStringify(this));

        adItem.data('cid', this.AddressKey);

        if (state.activeAddressKey != null && this.AddressKey == state.activeAddressKey) adItem.addClass('selected');

        adItem.bind('mouseover mouseout click', function(event) {
          switch (event.type) {
            case 'mouseover':
              $(this).addClass('hhAddress-list-item-hover');
              break;
            case 'mouseout':
              $(this).removeClass('hhAddress-list-item-hover');
              break;
            case 'click':
              $('.hhAddress-list-item.selected').removeClass('selected');
              $(this).addClass('selected');
              break;
          }
        });

        adList.append(adItem);
      });

      $('#hhExistingAddress').html(adList);

    }


    //merge button labels
    var btns = {};
    btns[gwManageHH.lblSetAddress] = function() {

      var createNew = $('#hhExistingAddress').hasClass('ui-accordion-content-active');

      if (!createNew) {
        state.activeAddressKey = null;
        state.activeStreet = $('#hhAddressStreet').val();
        state.activeCity = $('#hhAddressCity').val();
        state.activePostalCode = $('#hhAddressPostalCode').val();
        state.activeState = $('#hhAddressState').val();
        state.activeCountry = $('#hhAddressCountry').val();
      } else {

        var cid = $('#hhExistingAddress li.selected').data('cid');

        if (cid != undefined) {
          var addr = state.viableAddresses[cid];

          state.activeAddressKey = addr.AddressKey;
          state.activeStreet = addr.MailingStreet;
          state.activeCity = addr.MailingCity;
          state.activePostalCode = addr.MailingPostalCode;
          state.activeState = addr.MailingState;
          state.activeCountry = addr.MailingCountry;
        }
      }

      //write the address back to the household fields to use vanilla save functionality
      $('.sfField-MailingStreet__c').val(state.activeStreet);
      $('.sfField-MailingCity__c').val(state.activeCity);
      $('.sfField-MailingPostalCode__c').val(state.activePostalCode);
      $('.sfField-MailingState__c').val(state.activeState);
      $('.sfField-MailingCountry__c').val(state.activeCountry);

      gwManageHH.updateState(JSON.stringify(state));
      if (gwManageHH.jsonState != gwManageHH.originalState) $('.gwNotifications').gwNotify(gwManageHH.lblChangesNotSaved, {
        type: 'info'
      });
      $(this).dialog("close");
    };
    btns[gwManageHH.lblCancel] = function() {
      $(this).dialog("close");
    };
    dialog.dialog({
      modal: true,
      buttons: btns
    });
    var icons = {
      header: "ui-icon-bullet",
      headerSelected: "ui-icon-circle-check"
    };

    if (state.activeAddressKey == null)
      dialog.find('.gwAccordion').accordion({
        height: 350,
        icons: icons,
        active: 1
      });
    else
      dialog.find('.gwAccordion').accordion({
        height: 350,
        icons: icons
      });
  }

  gwManageHH.addMember = function(cid, wHH) {

    gwManageHH.jsonState = JSON.stringify(gwManageHH.state);

    $('.gwPreventUI').gwsetui('disable');

    pgController.remoteAddMember(cid, wHH, gwManageHH.jsonState, function(result, event) {
      if (event.type == 'exception') {
        $('.gwNotifications').gwNotify(event.message, {
          type: 'alert'
        });
      } else {
        if (result != null) {
          gwManageHH.updateState(result);
          if (gwManageHH.jsonState != gwManageHH.originalState) $('.gwNotifications').gwNotify(gwManageHH.lblChangesNotSaved, {
            type: 'info'
          });
        }
      }
      $('.gwPreventUI').gwsetui('enable');
    }, {
      escape: false
    });

  }

  gwManageHH.setInsertContacts = function() {
    var state = gwManageHH.state;
    var cards = $('.hhCard-new');

    state.insertContacts = new Array();
    cards.each(function() {
      var obj = $(this);
      var contact = obj.data('contact');
      if (contact.LastName != '' && contact.LastName != 'Last Name') {
        state.insertContacts.push(contact);
      }
    });
  }

  gwManageHH.removeMember = function(cid) {

    gwManageHH.jsonState = JSON.stringify(gwManageHH.state);

    $('.gwPreventUI').gwsetui('disable');

    pgController.remoteRemoveMember(cid, gwManageHH.jsonState, function(result, event) {

      if (event.type == 'exception') {
        $('.gwNotifications').gwNotify(event.message, {
          type: 'alert'
        });
      } else {
        if (result != null) {
          gwManageHH.updateState(result);
          if (gwManageHH.jsonState != gwManageHH.originalState) $('.gwNotifications').gwNotify(gwManageHH.lblChangesNotSaved, {
            type: 'info'
          });
        }
      }
      $('.gwPreventUI').gwsetui('enable');
    }, {
      escape: false
    });

  }

  gwManageHH.setNameExclusion = function(cid, ex) {

    gwManageHH.state.activeContacts[cid][fldNm('Naming_Exclusions__c')] = ex;

    gwManageHH.jsonState = JSON.stringify(gwManageHH.state);

    gwManageHH.setNaming();
  }

  /* Takes the values entered in the UI in relation to household naming and passes them to the remoteaction
  endpoint for the state to be updated */

  gwManageHH.setNaming = function() {

    var aN = $('#hhAutoName:checked').length > 0 ? true : false;
    var nN = $('#hhName').val();

    var aFG = $('#hhAutoFormalGreeting:checked').length > 0 ? true : false;
    var nFG = $('#hhFormalGreeting').val();

    var aIG = $('#hhAutoInformalGreeting:checked').length > 0 ? true : false;
    var nIG = $('#hhInformalGreeting').val();

    gwManageHH.jsonState = JSON.stringify(gwManageHH.state);

    $('.gwPreventUI').gwsetui('disable');

    pgController.remoteSetNaming(aN, nN, aFG, nFG, aIG, nIG, gwManageHH.jsonState, function(result, event) {
      if (event.type == 'exception') {
        $('.gwNotifications').gwNotify(event.message, {
          type: 'alert'
        });
      } else {
        if (result != null) {
          gwManageHH.updateState(result);
          if (gwManageHH.jsonState != gwManageHH.originalState) $('.gwNotifications').gwNotify(gwManageHH.lblChangesNotSaved, {
            type: 'info'
          });
        }
      }
      $('.gwPreventUI').gwsetui('enable');
    }, {
      escape: false
    });
  }

  gwManageHH.saveHousehold = function() {

    gwManageHH.jsonState = JSON.stringify(gwManageHH.state);

    $('.gwPreventUI').gwsetui('disable');

    var newHH = gwManageHH.state.hh.Id == null;

    pgController.remoteSave(gwManageHH.jsonState, function(result, event) {
      if (event.type == 'exception') {
        $('.gwNotifications').gwNotify(event.message, {
          type: 'alert'
        });
      } else {
        if (result != null) {
          gwManageHH.updateState(result);
          gwManageHH.originalState = JSON.stringify(gwManageHH.state);

          //$('.gwNotifications').gwNotify('Changes saved.', {type:'success'});
          if (!newHH) {
            $('input[id$="gwControls-StdSave"]').click();
          } else {
            window.location = '/' + gwManageHH.state.hh.Id;
          }
        }
      }
      $('.gwPreventUI').gwsetui('enable');
    }, {
      escape: false
    });
  }


  gwManageHH.renderMembers = function() {

    var members = gwManageHH.getHHMembers();
    var cids = new Array();

    //sort members by household naming order
    //members.sort(function(a,b){return a[fldNm('Household_Naming_Order__c')] === null ? 1 : b[fldNm('Household_Naming_Order__c')] === null ? -1 : (a[fldNm('Household_Naming_Order__c')] > b[fldNm('Household_Naming_Order__c')]) ? 1 : ((b[fldNm('Household_Naming_Order__c')] > a[fldNm('Household_Naming_Order__c')]) ? -1 : 0);} );

    // sort members by household naming order; contacts without naming order will be sorted by creation date.
    members.sort(function(a, b) {
      if (a[fldNm('Household_Naming_Order__c')] == null && b[fldNm('Household_Naming_Order__c')] == null) {
        if (a.CreatedDate > b.CreatedDate)
          return 1;
        if (a.CreatedDate < b.CreatedDate)
          return -1;
        return 0;
      }
      if (a[fldNm('Household_Naming_Order__c')] == null)
        return 1;
      if (b[fldNm('Household_Naming_Order__c')] == null)
        return -1;
      if (a[fldNm('Household_Naming_Order__c')] > b[fldNm('Household_Naming_Order__c')])
        return 1;
      if (a[fldNm('Household_Naming_Order__c')] < b[fldNm('Household_Naming_Order__c')])
        return -1;
      return 0;
    });

    // Add or update cards
    $(members).each(function(i) {

      var hasCard = $('#' + members[i].Id);
      cids.push(members[i].Id);

      if (hasCard.length < 1) {
        gwManageHH.renderCard(members[i]);
      } else {
        gwManageHH.updateCard(members[i]);
      }

    });


    $('.hhCard').not('.hhCard-new').each(function() {
      var cid = $(this).attr('id');

      // Check to see if the address is different from the active address
      var ct = gwManageHH.state.activeContacts[cid];
      if (ct != null && ct[fldNmNpsp('is_Address_Override__c')]) {
        $(this).find('.hhCard-details-address').addClass('gwAddressOverride');
      } else if (gwManageHH.state.useAddress == false || gwManageHH.compareAddress(cid) === true) {
        $(this).find('.hhCard-details-address').removeClass('gwModified');
      } else {
        $(this).find('.hhCard-details-address').addClass('gwModified');
      }


      // Cleanup any cards that were removed
      if ($.inArray(cid, cids) < 0) {
        $(this).hide().remove();
      }
    });
    if (members.length > 0) {
      $('.hhMembers-none').addClass('gwHidden');
    } else {
      $('.hhMembers-none').removeClass('gwHidden');
    }
  }

  gwManageHH.compareAddress = function(cid) {
    var state, contact, activeCon, newAddress, oldAddress;

    state = gwManageHH.state;
    contact = state.activeContacts[cid];

    if (contact != null && contact != undefined && (state.activeAddressKey != null || state.useAddress == true)) {
      if (state.useAddress === true) {
        activeCon = {
          MailingStreet: state.activeStreet,
          MailingCity: state.activeCity,
          MailingState: state.activeState,
          MailingPostalCode: state.activePostalCode,
          MailingCountry: state.activeCountry
        }
      } else {
        activeCon = state.viableAddresses[state.activeAddressKey];
      }

      newAddress = gwManageHH.addressStringify(contact);
      oldAddress = gwManageHH.addressStringify(activeCon);

      return newAddress == oldAddress;
    }
    return true;
  }

  gwManageHH.renderNaming = function() {
    var state = gwManageHH.state;
    var customNaming = '';

    $('.sfField-Name').val(state.hhName);
    $('.sfField-Formal_Greeting__c').val(state.hhFormalGreeting);
    $('.sfField-Informal_Greeting__c').val(state.hhInformalGreeting);

    if (state.autoName == true) {

      $('#hhAutoName').attr('checked', 'checked');

      $('#hhName').val(state.hhName);
      $('#hhName').attr('disabled', 'disabled').addClass('gwField-disabled', 200);

    } else {
      $('#hhAutoName').removeAttr('checked');

      $('#hhName').val(state.hhName);
      $('#hhName').removeAttr('disabled').removeClass('gwField-disabled', 200);

      customNaming += 'Name;';

    }

    if (state.autoFormalGreeting == true) {
      $('#hhAutoFormalGreeting').attr('checked', 'checked');

      $('#hhFormalGreeting').val(state.hhFormalGreeting);
      $('#hhFormalGreeting').attr('disabled', 'disabled').addClass('gwField-disabled', 200);

    } else {
      $('#hhAutoFormalGreeting').removeAttr('checked');

      $('#hhFormalGreeting').val(state.hhFormalGreeting);
      $('#hhFormalGreeting').removeAttr('disabled').removeClass('gwField-disabled', 200);

      customNaming += 'Formal_Greeting__c;';
    }

    if (state.autoInformalGreeting == true) {
      $('#hhAutoInformalGreeting').attr('checked', 'checked');

      $('#hhInformalGreeting').val(state.hhInformalGreeting);
      $('#hhInformalGreeting').attr('disabled', 'disabled').addClass('gwField-disabled', 200);

    } else {
      $('#hhAutoInformalGreeting').removeAttr('checked');

      $('#hhInformalGreeting').val(state.hhInformalGreeting);
      $('#hhInformalGreeting').removeAttr('disabled').removeClass('gwField-disabled', 200);

      customNaming += 'Informal_Greeting__c;';
    }

    $('.sfField-SYSTEM_CUSTOM_NAMING__c').val(customNaming);
  }

  gwManageHH.renderControls = function(enabled) {
    var hasContacts = $('.hhCard').length > 0;
    var inpts = $('.gwControls input[type="submit"]').not('.gwHidden');
    if (enabled) {
      inpts.removeAttr('disabled');
      inpts.css('opacity', '1');
      if (!hasContacts) {
        $('.gwControls-save').addClass('gwHidden');
        $('input[id$="gwControls-StdSave"]').attr('disabled', 'disabled');
      } else {
        $('.gwControls-save').removeClass('gwHidden');
        $('input[id$="gwControls-StdSave"]').removeAttr('disabled', 'disabled');
      }
    } else {
      inpts.attr('disabled', 'disabled');
      inpts.css('opacity', '0.5');
      inpts.val('Saving ...');
    }
  }

  gwManageHH.getHHMembers = function() {

    var members = new Array();
    var state = gwManageHH.state;

    var cmap = state.activeContacts;

    for (var id in cmap) {
      members.push(cmap[id]);
    }
    return members;
  }

  gwManageHH.renderAddress = function() {

    //Helper for state
    var state = gwManageHH.state;

    var hasContacts = false;
    var addString = '';
    for (var p in state.activeContacts) {
      hasContacts = true;
      break;
    }

    var addr;

    if (state.activeAddressKey == null) {
      addr = {
        MailingStreet: state.activeStreet,
        MailingCity: state.activeCity,
        MailingState: state.activeState,
        MailingPostalCode: state.activePostalCode,
        MailingCountry: state.activeCountry
      }
    } else {
      addr = state.viableAddresses[state.activeAddressKey];
    }

    // Primary address node in the DOM
    var prnode = $('.hhAddress');

    var adnode = $('.hhAddress-address');

    addString = gwManageHH.addressStringify(addr);

    //now use the useAddess flag to determine if address saved to contacts (always saved to household)
    if (state.useAddress == true)
      $('#hhCopyAddressToContacts').attr('checked', 'checked');
    else
      $('#hhCopyAddressToContacts').removeAttr('checked');

    adnode.html(addString);
    prnode.fadeIn(200);

  }

  gwManageHH.addressStringify = function(contact) {

    var address = new String();

    if (contact[fldNmNpsp('is_Address_Override__c')]) {
      address = 'using Address Override: <br/>';
    }

    if (contact.MailingStreet != null && contact.MailingStreet != '') {
      var strt = contact.MailingStreet.replace(/(\r\n|\n|\r)/gm, '<br />');
      address += strt;
      if (contact.MailingCity != null ||
        contact.MailingState != null ||
        contact.MailingPostalCode != null ||
        contact.MailingCountry != null) {
        address += '<br />';
      }
    }
    if (contact.MailingCity != null && contact.MailingCity != '') {
      address += contact.MailingCity + '<br />';
      //address += contact.MailingState != null && contact.MailingState != '' ? ', ' : '';
    }
    if (contact.MailingState != null && contact.MailingState != '') {
      address += contact.MailingState + '<br />';
    }
    if (contact.MailingPostalCode != null && contact.MailingPostalCode != '') {
      address += contact.MailingPostalCode + '<br />';
    }
    if (contact.MailingCountry != null && contact.MailingCountry != '') {
      address += contact.MailingCountry;
    }

    return address;
  }

  $.fn.gwNotify = function(message, options) {

    var obj, config, cur_msg;

    obj = $(this);

    cur_msg = obj.find('p.gwNotify-message').length > 0 ? obj.find('p.gwNotify-message').text() : '';

    if (cur_msg === message && message != '') return obj;

    if (message == undefined || message == '') {
      obj.fadeOut(200, function() {
        obj.find('p.gwNotify-message').text('');
      });
    }

    // set the default config
    config = $.extend({
      type: 'info',
      icons: {
        info: 'ui-icon-info',
        alert: 'ui-icon-alert',
        success: 'ui-icon-check'
      },
      cssClass: {
        info: 'ui-state-highlight',
        alert: 'gwError',
        success: 'gwSuccess'
      }
    }, options);



    if (obj.is(':hidden')) obj.css('opacity', '0').removeClass('gwHidden');

    if (obj.find('.gwNotify-message').length < 1) obj.html('<p class="gwNotify-message"></p>');

    /*if (obj.find('gwNotify-icon').length < 1) obj.prepend('<span class="gwNotify-icon"></span>');

    var ico = obj.find('.gwNotify-icon');
    ico.addClass(config.icons[config.type]);
    ico.addClass('ui-icon');
    obj.prepend(ico);*/

    obj.animate({
      opacity: 0
    }, 200, function() {
      // Insert message
      obj.find('p.gwNotify-message').text(message);
      // Apply classes
      obj.addClass('ui-corner-all');
      for (var c in config.cssClass) {
        obj.removeClass(config.cssClass[c]);
      }
      obj.addClass(config.cssClass[config.type]);
      obj.animate({
        opacity: 1.0
      }, 200);
    });

    return obj;
  }

  $.fn.gwsetui = function(options) {

    return $(this).each(function() {
      var obj;

      obj = $(this);

      if (options == 'enable') {

        if (obj.is('button')) {
          obj.button('enable').button('refresh');
        }
        if (obj.is('input')) {
          if (obj.is('.gwUIDisabled')) {
            obj.removeAttr('disabled');
          }
        }
        obj.removeClass('gwUIDisabled');
      }

      if (options == 'disable') {

        obj.not(':disabled').addClass('gwUIDisabled');

        if (obj.is('button')) {
          obj.button('disable').button('refresh');
        }
        if (obj.is('input')) {
          obj.attr('disabled', 'disabled');
        }
      }

      if (options == 'toggle') {

      }
    });
  }

})(jQuery.noConflict());
