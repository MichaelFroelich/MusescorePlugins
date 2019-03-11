import MuseScore 3.0

MuseScore {
  menuPath: "Plugins.Proof Reading.Intervals of Voices"
  version: "3.0"
  description: "Check intervals for voices"
  
  function vocalNote(note, voice, staff) {
    this.note = note;
    this.voice = voice;
    this.staff = staff;
  }
  
  function checkInterval(n1, n2) {
    var note1 = n1;
    var note2 = n2;
    
    if (note2.pitch < note1.pitch) {
      note1 = n2;
      note2 = n1;
    }
    var size = 0;
    var quality = "";
    var diff = note2.tpc - note1.tpc;
    if (diff >= -1 && diff <= 1) {
      quality = "P";
    } else if (diff >= 2 && diff <= 5) {
      quality = "M";
    } else if (diff >= 6 && diff <= 12) {
      quality = "+";
    } else if (diff >= 13 && diff <= 19) {
      quality = "++";
    } else if (diff <= -2 && diff >= -5) {
      quality = "m";
    } else if (diff <= -6 && diff >= -12) {
      quality = "d";
    } else if (diff <= -13 && diff >= -19) {
      quality = "dd";
    } else quality = "?";

    var circlediff = (28 + note2.tpc - note1.tpc) % 7;
    if (circlediff == 1) {
      size = 5;
    } else if (circlediff == 2) {
      size = 2;
    } else if (circlediff == 3) {
      size = 6;
    } else if (circlediff == 4) {
      size = 3;
    } else if (circlediff == 5) {
      size = 7;
    } else if (circlediff == 6) {
      size = 4;
    } else {
      if ((note2.pitch - note1.pitch) > 2)
        size = 8;
      else size = 1;
    }
    return quality + size;
  }

  function filterNotes(oldNotes, newNotes) {
    if (oldNotes == null || oldNotes.length == 0) {
      return newNotes;
    }
    var tempNotes = [];
    var outputNotes = [];

    for (var n = 0; n < oldNotes.length; n++) {
      var note = oldNotes[n];
      var indx = note.staff * 3 + note.voice;
      tempNotes[indx] = note;
    }
    for (var n = 0; n < newNotes.length; n++) {
      var note = newNotes[n];
      var indx = note.staff * 3 + note.voice;
      tempNotes[indx] = note;
    }

    var i = 0;
    for (var n = tempNotes.length - 1; n >= 0; n--) {
      if (tempNotes[n] && tempNotes[n].note) {
        outputNotes[i++] = tempNotes[n];
      }
    }
    return outputNotes;
  }

  function getAllCurrentNotes(cursor, startStaff, endStaff) {
    var oldvoice = cursor.voice;
    var oldstaff = cursor.staffIdx;
    var full_chord = [];
    var idx_note = 0;
    for (var staff = endStaff; staff >= startStaff; staff--) {
      for (var voice = 3; voice >= 0; voice--) {
        cursor.voice = voice;
        cursor.staffIdx = staff;
        var dag = new vocalNote();
        dag.voice = voice;
        dag.staff = staff;
        if (cursor.element && cursor.element.notes) {
          var notes = cursor.element.notes;
          for (var i = 0; i < notes.length; i++) {
            if(notes[i].tpc === 0) continue;
            dag.note = notes[i];
            full_chord[idx_note] = dag;
            idx_note++;
          }
        } else if(cursor.element && cursor.element.type == Element.REST) {
          dag.note = null;
          full_chord[idx_note] = dag;
          idx_note++;
        }
      }
    }
    cursor.voice = oldvoice;
    cursor.staffIdx = oldstaff;
    return full_chord;
  }

  onRun: {
    if (typeof curScore === 'undefined')
      Qt.quit();

    var ticks =[""];
    var cursor = curScore.newCursor();
    var startStaff;
    var endStaff;
    var endTick;
    var fullScore = false;
    var notes = [];

    cursor.rewind(1);
    if (!cursor.segment) { // no selection
      fullScore = true;
      startStaff = 0; // start with 1st staff
      endStaff = curScore.nstaves - 1; // and end with last
    } else {
      startStaff = cursor.staffIdx;
      cursor.rewind(2);
      if (cursor.tick === 0) {
        // this happens when the selection includes
        // the last measure of the score.
        // rewind(2) goes behind the last segment (where
        // there's none) and sets tick=0
        endTick = curScore.lastSegment.tick + 1;
      } else {
        endTick = cursor.tick;
      }
      endStaff = cursor.staffIdx;
    }

    for (var staff = startStaff; staff <= endStaff; staff++) {
      for (var voice = 0; voice < 4; voice++) {
        if (fullScore)  // no selection
          cursor.rewind(0); // beginning of score
        else
          cursor.rewind(1); // beginning of selection
        cursor.voice = voice;
        cursor.staffIdx = staff;
        while (cursor.element && (fullScore || cursor.tick < endTick)) {
          if (cursor.element.type === Element.CHORD) {
            var newNotes = getAllCurrentNotes(cursor, startStaff, endStaff);
            notes = filterNotes(notes, newNotes);

            for (var nn = 0; nn < notes.length - 1; nn++) {
              var nextNote  = null;
              for(var nnn = 1; nn + nnn < notes.length; nnn++)
                if(notes[nn + nnn] && notes[nn + nnn].note) {
                  nextNote = notes[nn + nnn];
                  break;
                }
              
              if(!nextNote.note || !notes[nn].note)
                  continue;
              var ticker = "";
              if(notes[nn].note.tick > nextNote.note.tick)
                ticker = notes[nn].note.track.toString() + notes[nn].note.tick.toString() + nextNote.note.track.toString() + nextNote.note.tick.toString() ;
             else
                ticker = nextNote.note.track.toString() + nextNote.note.tick.toString()  + notes[nn].note.track.toString() + notes[nn].note.tick.toString() ;

              if (ticks.indexOf(ticker.toString()) == -1) {
                ticks.push(ticker.toString());
              } else {
                continue;
              }

              var text = newElement(Element.STAFF_TEXT);
              text.text = checkInterval(notes[nn].note, nextNote.note);
              var nvoice = getLower(notes[nn], nextNote).voice;
              cursor.staffIdx = notes[nn].staff;
              
              switch (nvoice) {
                case 0: 
                case 3: 
                  //text.offsetY  = 10; 
                  text.placement = 1;
                  break;
              }
              if ((cursor.staffIdx - startStaff) % 2
                  && nvoice != 0) 
                  text.placement = 1;
              
              text.fontSize = 6;
              
              if ((voice == 0) && (notes[0].pitch > 83))
                text.offsetX  = 1;
              if (text.text.charAt(0) == "P")
                text.color = "#0000FF";
              else if (text.text.charAt(1) == "7" || text.text.charAt(1) == "2")
                text.color = "#FF0000";
              else if (text.text.charAt(0) == "m" || text.text.charAt(0) == "M")
                text.color = "#00FF00";
              else
                text.color = "#800080";
              cursor.staffIdx = nextNote.staff;
              cursor.voice = nvoice;
              cursor.add(text);
            }
          } // end if CHORD
          cursor.voice = voice;
          cursor.staffIdx = staff;
          cursor.next();
        } // end while segment
      } // end for voice
    } // end for staff
    Qt.quit();
  } // end onRun

  function getLower(note2, note1) {
    if (note2.note.pitch > note1.note.pitch) {
      return note1;
    }
    else {
      return note2;
    }
  }
}
