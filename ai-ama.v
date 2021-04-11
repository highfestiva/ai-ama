module main

import json
import math
import net.http
import os
import rand.util
import time
import vweb

const (
	port = 8083

	url_points = map{
		'%0D': ''
		'%0A': '\n'
		'+': ' '

		'%20': ' '
		'%21': '!'
		'%22': '"'
		'%23': '#'
		'%24': '$'
		'%25': '%'
		'%26': '&'
		'%27': "'"
		'%28': '('
		'%29': ')'
		'%2A': '*'
		'%2B': '+'
		'%2C': ','
		'%2D': '-'
		'%2E': '.'
		'%2F': '/'

		'%3A': ':'
		'%3B': ';'
		'%3C': '<'
		'%3D': '='
		'%3E': '>'
		'%3F': '?'

		'%40': '@'

		'%5B': '['
		'%5C': '\\'
		'%5D': ']'
		'%5E': '^'
		'%5F': '_'

		'%60': '‘'

		'%7B': '{'
		'%7D': '}'
		'%7C': '|'
		'%7E': '~'
	}

	questions = [
		'How old is the sun?'
		'When was the last ice age?'
		'What year was the Golden Gate Bridge built?'
		'How tall is the Empire State Building?'
		'How much does the Eiffel Tower weigh?'
		'How far is the nearest star?'
		'Which is the largest known star?'
		'How long was the T-Rex?'
		'At what altitude do geo-stationary satellites fly?'
		'What do cuckoos feed on?'
		'Which is Will Smith\'s most famous movie?'
		'Name two Swedish figher jets.'
		'Who built Coral Castle?'
		'How many languages are spoken in Indonesia?'
		'What is the life span of a panther?'
		'Which is the nearest star?'
		'How do you say \'good morning\' in Swedish?'
		'How long time did Nelson Mandela spend in prison?'
		'Who invented the airplane?'
		'Which are smartest, cats or pigs?'
		'How many eggs does an average eagle lay?'
		'Which tree is the tallest?'
		'How many people live in Mexico?'
		'How many pounds to a kilo?'
		'Who is Jerry Seinfeldt?'
		'Who\'s the president of Canada?'
		'How deep do oil-rig divers go?'
		'When did the Tunguska meteor strike happen?'
		'How high can the SR-71 fly?'
		'When did the Sovjet submarine U-137 beach in Sweden?'
	]

	open_ai_api_key = os.read_file('.oai.key') or { panic('Missing OpenAI key file!') }
)

struct App {
	vweb.Context
}

struct Choice {
	text string
}

struct Answer {
	choices []Choice
}

fn main() {
	vweb.run<App>(port)
}

fn unurl(s string) string {
	mut t := s
	for p,r in url_points {
		t = t.replace(p, r)
	}
	return t
}

fn map_post(params string) map[string]string {
	p := unurl(params)
	mut m := map[string]string{}
	for s in p.split('&') {
		kv := s.split('=')
		m[kv[0]] = kv[1]
	}
	return m
}

fn hashish(i string) string {
	mut hash := 0
	for ch in i {
		hash = ((hash<<5)-hash) + ch
		hash &= 0xFFFFFFFF
		//println('$ch $hash')
	}
	return hash.str()
}

pub fn (mut app App) init_once() {
	app.serve_static('/favicon.ico', 'static/favicon.ico', 'img/x-icon')
	app.serve_static('/static/ai.jpg', 'static/ai.jpg', 'image/jpeg')
	app.handle_static('.', false)
}

pub fn (mut app App) index() vweb.Result {
	return app.ok()
}

[post]
fn (mut app App) ask() vweb.Result {
	req_params := map_post(app.req.data)
	if req_params['question'].len == 0 {
		return app.msg('Enter a question.')
	}
	epoch := req_params['nounce']
	now := time.utc().unix_time()
	/*println(epoch)
	println(now)*/
	if math.fabs(epoch.i64()-now) > 30 {
		return app.msg("Your computer's time setting is off, fix or die!")
	}
	hash := req_params['hash']
	/*println(hash)
	println(hashish(epoch))*/
	if hash != hashish(epoch).str() {
		return app.msg("Hackarroo!?!")
	}
	prompt := (req_params['pre_questions'] + req_params['question'] + '\nA: ').replace('\n', '\\n')
	//println(prompt)
	data := '{ "prompt": "${prompt}", "temperature": 0, "max_tokens": 150, "top_p": 1, "frequency_penalty": 0.0, "presence_penalty": 0.0, "stop": ["\\n"] }'
	header := http.new_header(http.HeaderConfig{http.CommonHeader.authorization, 'Bearer '+open_ai_api_key}, http.HeaderConfig{http.CommonHeader.content_type, 'application/json'})
	conf := http.FetchConfig{method: .post, data: data, header: header}
	resp := http.fetch('https://api.openai.com/v1/engines/davinci/completions', conf) or {
		println('fetch error')
		return app.server_error(400)
	}
	//println(resp)
	oai_answer := json.decode(Answer, resp.text) or {
		println('decode error')
		return app.index()
	}
	if oai_answer.choices[0].text.len == 0 {
		println('missing answer')
		return app.index()
	}
	/*println(oai_answer)
	println(oai_answer.choices[0].text)*/
	ans := unurl(oai_answer.choices[0].text[2..])
	//println(ans)
	pre_questions := (prompt + ans).replace('\\n', '\n') + '\nQ: '
	last_question := 'Q: ' + req_params['question']
	last_answer := 'A: ' + ans
	println('$last_question   $last_answer')
	default_question := ''
	placeholder := util.sample_r(questions, 1)[0]
	return app.ans(pre_questions, last_question, last_answer, '', default_question, placeholder)
}

fn (mut app App) ok() vweb.Result {
	return app.msg('')
}

fn (mut app App) msg(msg string) vweb.Result {
	pre_questions := 'Q: How many planets are in the solar system?\nA: The solar system contains eight planets.\nQ: When do dolphins become adults?\nA: When they are seven years old.\nQ: '
	last_question := ''
	last_answer := ''
	qs := util.sample_nr(questions, 2)
	default_question := qs[0]
	placeholder := qs[1]
	return app.ans(pre_questions, last_question, last_answer, msg, default_question, placeholder)
}

fn (mut app App) ans(pre_questions string, last_question string, last_answer string, msg string, default_question string, placeholder string) vweb.Result {
	return $vweb.html()
}
