'use strict';

/** **********************************************************************
 * VotingAppWrapper
 */

module.exports = (function ($) {

    const batchSize = 5;
    const batchTime = 250;
    const imageDir = 'pokeart/';

    /**
     * @param {DOMNode} buttonParentNode
     *   Where the control button should be inserted in the DOM
     *
     * @param {Array} list
     *   List of pokemon to preload, each with properties:
     *     .generation
     *     .imageUrl
     */
    let Preloader = function (buttonParentNode, list)
    {
        this.doPreload = (location.search !== "?nopreload");
        this.list = [];
        this.timer = null;
        this.images = [];
        this.generation = 1;
        this.letter = 'A';
        this.installButton(buttonParentNode);
        this.queue(list);
    };

    Preloader.prototype.installButton = function (parentNode)
    {
        let me = this;
        $(document).ready(function () {
            me.$button = $(parentNode)
                .append('<span id="preload-controls" class="fa" style="display:none"></span>')
                .children()
                .first()
                .on('click', function (e) {
                    me.toggle();
                });
        });
    };

    Preloader.prototype.setButton = function (state)
    {
        if (!this.$button) {
            return;
        }
        if (state === 'play') {
            this.$button.show().addClass('fa-play').removeClass('fa-pause')[0].title = 'resume preloading';
        } else if (state === 'pause') {
            this.$button.show().addClass('fa-pause').removeClass('fa-play')[0].title = 'pause preloading';
        } else {
            this.$button.hide();
        }
    };

    Preloader.prototype.queue = function (list) {
        if (list instanceof Array) {
            this.list = this.list.concat(list);
        }
        this.schedule();
    };

    Preloader.prototype.schedule = function () {
        if (this.doPreload && !this.timer && this.list.length) {
            this.timer = setTimeout(this.preloadImages.bind(this), batchTime);
        }
        this.updateButton();
    };

    Preloader.prototype.updateButton = function () {
        if (!this.doPreload) {
            // no preloading whatsoever.
            this.setButton('hide');
        } else if (!this.list.length) {
            // nothing to preload.
            this.setButton('hide');
        } else if (!this.timer) {
            // not preloading right now.
            this.setButton('play');
        } else {
            // we are preloading right now.
            this.setButton('pause');
        }
    };

    Preloader.prototype.resume = Preloader.prototype.schedule;

    Preloader.prototype.pause = function ()
    {
        if (this.timer) {
            clearTimeout(this.timer);
            this.timer = null;
            this.updateButton();
        }
    };

    Preloader.prototype.toggle = function ()
    {
        if (this.timer) {
            this.pause();
        } else {
            this.resume();
        }
    };

    Preloader.prototype.preloadImages = function ()
    {
        const prevGeneration = this.generation;
        const prevLetter = this.letter;
        for (let i = 0; i < Math.min(batchSize, this.list.length); i += 1) {
            let nextImg = this.list.shift();
            this.generation = nextImg.generation;
            this.letter = nextImg.letter;
            this.images[i] = new Image();
            this.images[i].src = imageDir + nextImg.imageUrl;
        }
        this.timer = null;
        if (this.list.length) {
            this.schedule();
        } else {
            this.updateButton();
        }
    };

    return Preloader;

})($); // $ is the cash library

