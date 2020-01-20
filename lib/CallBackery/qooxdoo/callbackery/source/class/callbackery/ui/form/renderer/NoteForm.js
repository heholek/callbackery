/* ************************************************************************
   Copyright: 2013 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/**
 * A special renderer for AutoForms which includes notes below the section header
 * widget and next to the individual form widgets.
 */
qx.Class.define("callbackery.ui.form.renderer.NoteForm", {
    extend : qx.ui.form.renderer.Single,
    /**
     * create a page for the View Tab with the given title
     *
     * @param vizWidget {Widget} visualization widget to embed
     */
    construct: function(form) {
        this.base(arguments,form);
        var fl = this._getLayout();
        // have plenty of space for input, not for the labels
        fl.setColumnFlex(0, 0);
        fl.setColumnAlign(0, "left", "top");
        fl.setColumnFlex(1, 4);
        fl.setColumnMinWidth(1, 130);
        fl.setColumnFlex(2,1);
        fl.setColumnMaxWidth(2,250);
        fl.setSpacingY(0);
    },

    members: {
        addItems: function(items,names,title,itemOptions,headerOptions){
            // add the header
            if (title != null) {
                this._add(
                    this._createHeader(title), {row: this._row, column: 0, colSpan: 3}
                );
                this._row++;
                if (headerOptions != null && headerOptions.note != null){
                    this._add(new qx.ui.basic.Label(headerOptions.note).set({
                        rich: true,
                        alignX: 'left'
                    }),{ row: this._row, column: 0, colSpan: 3});
                    this._row++;
                }
            }

            // add the items
            var msg = callbackery.ui.MsgBox.getInstance();
            for (var i = 0; i < items.length; i++) {
                var label = this._createLabel(names[i], items[i]);
                label.set({
                    marginTop: 2,
                    marginBottom: 2
                });
                this._add(label, {row: this._row, column: 0});
                var item = items[i];
                item.set({
                    marginTop: 2,
                    marginBottom: 2
                });
                label.setBuddy(item);
                this._add(item, {row: this._row, column: 1});
                if (itemOptions != null && itemOptions[i] != null) {
                    if ( itemOptions[i].note ){
                        this._add(new qx.ui.basic.Label(itemOptions[i].note).set({
                            rich: true,
                            marginLeft: 20,
                            marginRight: 20
                        }),{
                            row: this._row,
                            column: 2
                        });
                    }
                }
                if ( itemOptions[i].copyOnTap
                        && item.getReadOnly()){
                    var that = this;
                    item.addListener('tap',function(e){
                        try {
                            navigator.clipboard.writeText(item.getValue())
                            .then(function(err){ msg.info(that.tr("Text Copied"),that.tr("The Text has been copied to clipboard"))})
                            .catch(function(err){ msg.info(that.tr("Copy failed"),that.tr("Select text and press [ctr]+[c]")) });
                        } catch (err) {
                            msg.info(that.tr("Copy Failed"),that.tr("Select text with the Mouse and press [ctr]+[c]"))
                        }
                    });
                }
                this._row++;
                this._connectVisibility(item, label);
            // store the names for translation
            if (qx.core.Environment.get("qx.dynlocale")) {
                  this._names.push({name: names[i], label: label, item: items[i]});
            }
         }
        }
    }
});
