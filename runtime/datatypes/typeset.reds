Red/System [
	Title:   "Typeset datatype runtime functions"
	Author:  "Xie Qingtian"
	File: 	 %typeset.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2015 Nenad Rakocevic & Xie Qingtian. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/dockimbel/Red/blob/master/BSL-License.txt
	}
]

typeset: context [
	verbose: 0

	#enum typeset-op! [
		OP_MAX											;-- calculate highest value
		OP_SET											;-- set value bits
		OP_TEST											;-- test if value bits are set
		OP_CLEAR										;-- clear value bits
		OP_UNION
		OP_AND
		OP_OR
		OP_XOR
	]
	
	make-default: func [
		blk [red-block!]
		/local
			ts	  [red-typeset!]
			bits  [int-ptr!]
			bbits [byte-ptr!]
	][
		ts: as red-typeset! ALLOC_TAIL(blk)
		ts/header: TYPE_TYPESET						;-- implicit reset of all header flags
		
		bits: as int-ptr! ts
		bits/2: FFFFFFFFh
		bits/3: FFFFFFFFh
		bits/4: FFFFFFFFh
		
		bbits: as byte-ptr! bits + 1
		BS_CLEAR_BIT(bbits TYPE_UNSET)
	]
	
	make-in: func [
		blk	  [red-block!]
		spec  [red-block!]
		/local
			ts	  [red-typeset!]
			ts2	  [red-typeset!]
			value [red-value!]
			end	  [red-value!]
			type  [red-datatype!]
	][
		assert TYPE_OF(spec) = TYPE_BLOCK
		ts: as red-typeset! ALLOC_TAIL(blk)
		ts/header: TYPE_TYPESET						;-- implicit reset of all header flags
		clear ts
		
		value: block/rs-head spec
		end:   block/rs-tail spec

		while [value < end][
			type: as red-datatype! value
			
			if TYPE_OF(value) = TYPE_WORD [
				type: as red-datatype! word/get as red-word! value
			]
			switch TYPE_OF(type) [
				TYPE_DATATYPE [
					set-type ts value
				]
				TYPE_TYPESET  [
					ts2: as red-typeset! value
					copy-memory 
						(as byte-ptr! ts)  + 4
						(as byte-ptr! ts2) + 4
						12
				]
			]
			value: value + 1
		]
	]

	do-bitwise: func [
		type	[integer!]
		return: [red-typeset!]
		/local
			res   [red-typeset!]
			set1  [red-typeset!]
			set2  [red-typeset!]
	][
		set1: as red-typeset! stack/arguments
		set2: set1 + 1
		res: as red-typeset! stack/push*
		res/header: TYPE_TYPESET
		clear res
		if TYPE_OF(set2) = TYPE_DATATYPE [
			set-type res as red-value! set2
			set2: res
		]
		switch type [
			OP_UNION
			OP_OR	[
				res/array1: set1/array1 or set2/array1
				res/array2: set1/array2 or set2/array2
				res/array3: set1/array3 or set2/array3
			]
			OP_AND	[
				res/array1: set1/array1 and set2/array1
				res/array2: set1/array2 and set2/array2
				res/array3: set1/array3 and set2/array3
			]
			OP_XOR	[
				res/array1: set1/array1 xor set2/array1
				res/array2: set1/array2 xor set2/array2
				res/array3: set1/array3 xor set2/array3
			]
		]
		stack/set-last as red-value! res
		res
	]

	union: func [
		case?	[logic!]
		skip	[red-value!]
		return: [red-typeset!]
	][
		do-bitwise OP_UNION
	]

	and~: func [return:	[red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "typeset/and~"]]
		as red-value! do-bitwise OP_AND
	]

	or~: func [return:	[red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "typeset/or~"]]
		as red-value! do-bitwise OP_OR
	]

	xor~: func [return:	[red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "typeset/xor~"]]
		as red-value! do-bitwise OP_XOR
	]

	push: func [
		sets [red-typeset!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/push"]]

		copy-cell as red-value! sets stack/push*
	]

	set-type: func [
		sets	[red-typeset!]
		value	[red-value!]
		/local
			type [red-datatype!]
			id   [integer!]
			bits [byte-ptr!]
	][
		type: as red-datatype! value
		if TYPE_OF(type) = TYPE_WORD [
			type: as red-datatype! word/get as red-word! type
		]
		if TYPE_OF(type) <> TYPE_DATATYPE [
			fire [TO_ERROR(script invalid-arg) value]
		]
		id: type/value
		assert id < 96
		bits: (as byte-ptr! sets) + 4					;-- skip header
		BS_SET_BIT(bits id)
	]

	;-- Actions --

	make: func [
		proto	[red-value!]
		spec	[red-value!]
		return: [red-typeset!]
		/local
			sets [red-typeset!]
			type [red-value!]
			blk	 [red-block!]
			i	 [integer!]
			end  [red-value!]
			s	 [series!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/make"]]

		sets: as red-typeset! stack/push*
		sets/header: TYPE_TYPESET						;-- implicit reset of all header flags
		clear sets

		either TYPE_OF(spec) = TYPE_BLOCK [
			blk: as red-block! spec
			s: GET_BUFFER(blk)
			i: blk/head
			end: s/tail
			type: s/offset + i

			while [type < end][
				set-type sets type
				i: i + 1
				type: s/offset + i
			]
		][
			fire [TO_ERROR(script bad-make-arg) proto spec]
		]
		sets
	]

	form: func [
		sets	[red-typeset!]
		buffer	[red-string!]
		arg		[red-value!]
		part	[integer!]
		return: [integer!]
		/local
			array	[byte-ptr!]
			value	[integer!]
			id		[integer!]
			base	[integer!]
			cnt		[integer!]
			s		[series!]
			part?	[logic!]
			set?	[logic!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/form"]]

		part?: OPTION?(arg)
		array: (as byte-ptr! sets) + 4
		id: 1
		cnt: 0
		string/concatenate-literal buffer "make typeset! ["
		part: part - 15
		until [
			BS_TEST_BIT(array id set?)
			if set? [
				if all [part? negative? part][return part]
				name: name-table + id
				string/concatenate-literal-part buffer name/buffer name/size + 1
				string/append-char GET_BUFFER(buffer) as-integer space
				part: part - name/size - 2
				cnt: cnt + 1
			]
			id: id + 1
			id > datatype/top-id
		]
		s: GET_BUFFER(buffer)
		either zero? cnt [
			string/append-char s as-integer #"]"
		][
			string/poke-char s (as byte-ptr! s/tail) - 1 as-integer #"]"
		]
		part
	]

	mold: func [
		sets	[red-typeset!]
		buffer	[red-string!]
		only?	[logic!]
		all?	[logic!]
		flat?	[logic!]
		arg		[red-value!]
		part	[integer!]
		return:	[integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/mold"]]

		form sets buffer arg part
	]

	compare: func [
		set1	[red-typeset!]							;-- first operand
		set2   	[red-typeset!]							;-- second operand
		op		[integer!]								;-- type of comparison
		return: [integer!]
		/local
			type  [integer!]
			res	  [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/compare"]]

		type: TYPE_OF(set2)
		if type <> TYPE_TYPESET [RETURN_COMPARE_OTHER]
		switch op [
			COMP_EQUAL
			COMP_STRICT_EQUAL
			COMP_NOT_EQUAL
			COMP_SORT
			COMP_CASE_SORT [
				res: SIGN_COMPARE_RESULT((length? set1) (length? set2))
			]
			default [
				res: -2
			]
		]
		res
	]

	complement: func [
		sets	[red-typeset!]
		return:	[red-value!]
		/local
			res [red-typeset!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/complement"]]

		res: as red-typeset! copy-cell as red-value! sets stack/push*
		res/array1: not res/array1
		res/array2: not res/array2
		res/array3: not res/array3
		as red-value! res
	]

	clear: func [
		sets	[red-typeset!]
		return:	[red-value!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/clear"]]

		sets/array1: 0
		sets/array2: 0
		sets/array3: 0
		as red-value! sets
	]

	find: func [
		sets	 [red-typeset!]
		value	 [red-value!]
		part	 [red-value!]
		only?	 [logic!]
		case?	 [logic!]
		any?	 [logic!]
		with-arg [red-string!]
		skip	 [red-integer!]
		last?	 [logic!]
		reverse? [logic!]
		tail?	 [logic!]
		match?	 [logic!]
		return:	 [red-value!]
		/local
			id	 [integer!]
			type [red-datatype!]
			set? [logic!]
			array [byte-ptr!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/find"]]

		if TYPE_OF(value) <> TYPE_DATATYPE [
			print-line "Find Error: invalid argument"
			return as red-value! false-value
		]
		array: (as byte-ptr! sets) + 4
		type: as red-datatype! value
		id: type/value
		assert id < 96
		BS_TEST_BIT(array id set?)
		as red-value! either set? [true-value][false-value]
	]

	insert: func [
		sets	 [red-typeset!]
		value	 [red-value!]
		part-arg [red-value!]
		only?	 [logic!]
		dup-arg	 [red-value!]
		append?	 [logic!]
		return:	 [red-value!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/insert"]]

		set-type sets value
		as red-value! sets
	]

	length?: func [
		sets	[red-typeset!]
		return: [integer!]
		/local
			arr [byte-ptr!]
			cnt [integer!]
			id  [integer!]
			set? [logic!]
	][
		#if debug? = yes [if verbose > 0 [print-line "typeset/length?"]]

		id:  1
		cnt: 0
		arr: (as byte-ptr! sets) + 4
		until [
			BS_TEST_BIT(arr id set?)
			if set? [cnt: cnt + 1]
			id: id + 1
			id > datatype/top-id
		]
		cnt
	]

	init: does [
		datatype/register [
			TYPE_TYPESET
			TYPE_VALUE
			"typeset!"
			;-- General actions --
			:make
			null			;random
			null			;reflect
			null			;to
			:form
			:mold
			null			;eval-path
			null			;set-path
			:compare
			;-- Scalar actions --
			null			;absolute
			null			;add
			null			;divide
			null			;multiply
			null			;negate
			null			;power
			null			;remainder
			null			;round
			null			;subtract
			null			;even?
			null			;odd?
			;-- Bitwise actions --
			:and~
			:complement
			:or~
			:xor~
			;-- Series actions --
			null			;append
			null			;at
			null			;back
			null			;change
			:clear
			null			;copy
			:find
			null			;head
			null			;head?
			null			;index?
			:insert
			:length?
			null			;next
			null			;pick
			null			;poke
			null			;remove
			null			;reverse
			null			;select
			null			;sort
			null			;skip
			null			;swap
			null			;tail
			null			;tail?
			null			;take
			null			;trim
			;-- I/O actions --
			null			;create
			null			;close
			null			;delete
			null			;modify
			null			;open
			null			;open?
			null			;query
			null			;read
			null			;rename
			null			;update
			null			;write
		]
	]
]