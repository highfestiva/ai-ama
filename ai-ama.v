module main

import json
import math
import net.http
import net.urllib
import os
import rand.util
import time
import vweb

const (
	port            = 8083

	questions       = [
		'How old is the sun?',
		'When was the last ice age?',
		'What year was the Golden Gate Bridge built?',
		'How tall is the Empire State Building?',
		'How much does the Eiffel Tower weigh?',
		'How far is the nearest star?',
		'Which is the largest known star?',
		'How long was the T-Rex?',
		'At what altitude do geo-stationary satellites fly?',
		'What do cuckoos feed on?',
		"Which is Will Smith's most famous movie?",
		'Name two Swedish fighter jets.',
		'Who built Coral Castle?',
		'How many languages are spoken in Indonesia?',
		'What is the life span of a panther?',
		'Which is the nearest star?',
		"How do you say 'good morning' in Swedish?",
		'How long time did Nelson Mandela spend in prison?',
		'Who invented the airplane?',
		'Which are smartest, cats or pigs?',
		'How many eggs does an average eagle lay?',
		'Which tree is the tallest?',
		'How many people live in Mexico?',
		'How many pounds to a kilo?',
		'Who is Jerry Seinfeldt?',
		"Who's the president of Canada?",
		'How deep do oil-rig divers go?',
		'When did the Tunguska meteor strike happen?',
		'How high can the SR-71 fly?',
		'When did the Sovjet submarine U-137 beach in Sweden?',
		'Was Jeffery Epstein a Mossad spy?',
		'Was Charlie Chaplin a friend of Winston Churchill?',
		'What does the theory of relativity say?',
		'What did Henry Ford invent?',
		'Is parenthood filled with constant cleaning?',
		'How common is back pain?',
		'In what part of the world is starvation most common?',
		'Which country is the largest?',
		'Can you do my homework?',
		'How does circular economy work?',
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

fn map_post(params string) map[string]string {
	p := urllib.query_unescape(params) or { '' }
	mut m := map[string]string{}
	for s in p.replace('\r', '').split('&') {
		kv := s.split('=')
		m[kv[0]] = kv[1]
	}
	return m
}

fn hashish(i string) string {
	mut hash := 0
	for ch in i {
		hash = ((hash << 5) - hash) + ch
		hash &= 0xFFFFFFFF
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
	// println(app.req.data)
	req_params := map_post(app.req.data)
	// println(req_params)
	if req_params['question'].len == 0 {
		return app.msg('Enter a question.')
	}
	epoch := req_params['nounce']
	now := time.utc().unix_time()
	if math.fabs(epoch.i64() - now) > 30 {
		return app.msg("Your computer's time setting is off, fix or die!")
	}
	hash := req_params['hash']
	if hash != hashish(epoch).str() {
		return app.msg('Hackarroo!?!')
	}
	prompt := (req_params['pre_questions'] + req_params['question'] + '\nA: ').replace('\n',
		'\\n').replace('"', '\\"')

	data := '{ "prompt": "$prompt", "temperature": 0, "max_tokens": 150, "top_p": 1, "frequency_penalty": 0.0, "presence_penalty": 0.0, "stop": ["\\n"] }'
	// println(data)
	header := http.new_header(http.HeaderConfig{http.CommonHeader.authorization, 'Bearer ' +
		open_ai_api_key}, http.HeaderConfig{http.CommonHeader.content_type, 'application/json'})
	conf := http.FetchConfig{
		method: .post
		data: data
		header: header
	}
	resp := http.fetch('https://api.openai.com/v1/engines/davinci/completions', conf) or {
		println('fetch error')
		return app.server_error(400)
	}
	oai_answer := json.decode(Answer, resp.text) or {
		println('decode error')
		return app.index()
	}
	if oai_answer.choices[0].text.len == 0 {
		println('missing answer')
		return app.index()
	}
	ans := urllib.query_unescape(oai_answer.choices[0].text[2..]) or {
		panic('GPT-3 returned nonsense: $oai_answer')
	}
	pre_questions := (prompt + ans).replace('\\n', '\n').replace('\\"', '"') + '\nQ: '
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
