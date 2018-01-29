var exec = require("cordova/exec");

/** 
    attribute SpeechGrammarList grammars;
    attribute DOMString lang;
    attribute boolean continuous;
    attribute boolean interimResults;
    attribute unsigned long maxAlternatives;
    attribute DOMString serviceURI;
 */
var SpeechRecognition = function () {
    this.grammars = null;
    this.lang = "en";
    this.continuous = false;
    this.interimResults = false;
    this.maxAlternatives = 1;
    this.serviceURI = "";
    
    // event methods
    this.onaudiostart = null;
    this.onsoundstart = null;
    this.onspeechstart = null;
    this.onspeechend = null;
    this.onsoundend = null;
    this.onaudioend = null;
    this.onresult = null;
    this.onnomatch = null;
    this.onerror = null;
    this.onstart = null;
    this.onend = null;
    this.onready = null;
    this.onrms = null;

    exec(function() {
        console.log("initialized");
    }, function(e) {
        console.log("error: " + e);
    }, "SpeechRecognition", "init", []);
};

SpeechRecognition.prototype.start = function() {
    var that = this;
    var successCallback = function(event) {
        if (event.type === "audiostart" && typeof that.onaudiostart === "function") {
            that.onaudiostart(event);
        } else if (event.type === "soundstart" && typeof that.onsoundstart === "function") {
            that.onsoundstart(event);
        } else if (event.type === "speechstart" && typeof that.onspeechstart === "function") {
            that.onspeechstart(event);
        } else if (event.type === "speechend" && typeof that.onspeechend === "function") {
            that.onspeechend(event);
        } else if (event.type === "soundend" && typeof that.onsoundend === "function") {
            that.onsoundend(event);
        } else if (event.type === "audioend" && typeof that.onaudioend === "function") {
            that.onaudioend(event);
        } else if (event.type === "result" && typeof that.onresult === "function") {
            that.onresult(event);
        } else if (event.type === "nomatch" && typeof that.onnomatch === "function") {
            that.onnomatch(event);
        } else if (event.type === "start" && typeof that.onstart === "function") {
            that.onstart(event);
        } else if (event.type === "end" && typeof that.onend === "function") {
            that.onend(event);
        } else if (event.type === "readyforspeech" && typeof that.onready === "function") {
            that.onready(event);
        } else if (event.type === "rms" && typeof that.onrms === "function") {
            that.onrms(event);
        }
    };
    var errorCallback = function(err) {
        if (typeof that.onerror === "function") {
            that.onerror(err);
        }
    };

    exec(successCallback, errorCallback, "SpeechRecognition", "start", [this.lang,this.interimResults,this.maxAlternatives,this.continuous]);
};

SpeechRecognition.prototype.stop = function() {
    exec(null, null, "SpeechRecognition", "stop", []);
};

SpeechRecognition.prototype.abort = function() {
    exec(null, null, "SpeechRecognition", "abort", []);
};

SpeechRecognition.prototype.requestPermissionForMic = function(success, fail) {
    exec(success, fail, "SpeechRecognition", "requestPermissionForMic", []);
};

SpeechRecognition.prototype.requestPermissionForRecognition = function(success, fail) {
    exec(success, fail, "SpeechRecognition", "requestPermissionForRecognition", []);
};

module.exports = SpeechRecognition;
