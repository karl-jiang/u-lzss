window.alert = function(hoge){
    if(confirm(hoge)){
    }else{
	throw "";
    }
}

function check(code, string){
    var logElm = document.getElementById("log");
    if(ULZSS.decode(code) != string){
	logElm.innerHTML += string + " error!\n";
	logElm.innerHTML += ULZSS.decode(code) + "\n";
    }else{
	logElm.innerHTML += string + " ok!\n";
    }
}

function check_convert(string){
    var code = ULZSS.encode(string);
    //alert(code);
    var logElm = document.getElementById("log");
    if(ULZSS.decode(code) != string){
	logElm.innerHTML += string + " error!\n";
	logElm.innerHTML += ULZSS.decode(code) + "\n";
    }else{
	logElm.innerHTML += string + " ok!\n";
    }
}


check("0hoge\u6024",  "hogehogehoge");
check("(あなた\u1023かぜ", "あなたあなたかぜ");

check_convert("hogehogehoge");
check_convert("あなたあなたかぜ");
check_convert('http://b.hatena.ne.jp/entry/http://b.hatena.ne.jp/entry/http://b.hatena.ne.jp/entry/http://b.hatena.ne.jp/entry/http://b.hatena.ne.jp/entry/http://b.hatena.ne.jp/entry/http://homepage.mac.com/naoyuki_hashimoto/iblog/C1310380191/E20060110214546/index.html')


