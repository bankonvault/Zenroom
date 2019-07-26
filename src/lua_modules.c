/*  Zenroom (DECODE project)
 *
 *  (c) Copyright 2017-2018 Dyne.org foundation
 *  designed, written and maintained by Denis Roio <jaromil@dyne.org>
 *
 * This source code is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Public License as published
 * by the Free Software Foundation; either version 3 of the License,
 * or (at your option) any later version.
 *
 * This source code is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * Please refer to the GNU Public License for more details.
 *
 * You should have received a copy of the GNU Public License along with
 * this source code; if not, write to:
 * Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <stdio.h>
#include <errno.h>
#include <jutils.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <lua_functions.h>

#include <zenroom.h>
#include <zen_error.h>

extern int lualibs_load_all_detected(lua_State *L);
extern int lua_cjson_safe_new(lua_State *l);
// extern int lua_cjson_new(lua_State *l);
extern int luaopen_cmsgpack_safe(lua_State *l);

// from lualibs_detected (generated by make embed-lua)
extern zen_extension_t zen_extensions[];
// extern unsigned char zen_lua_init[];
// extern unsigned int zen_lua_init_len;

// extern int luaopen_crypto(lua_State *L);
extern int luaopen_octet(lua_State *L);
// extern int luaopen_rsa(lua_State *L);
extern int luaopen_ecdh(lua_State *L);
extern int luaopen_ecp(lua_State *L);
extern int luaopen_ecp2(lua_State *L);
extern int luaopen_fp12(lua_State *L);
extern int luaopen_big(lua_State *L);
extern int luaopen_rng(lua_State *L);
extern int luaopen_hash(lua_State *L);

// really loaded in lib/lua53/linit.c
// align here for reference
luaL_Reg lualibs[] = {
//	{LUA_LOADLIBNAME, luaopen_package},
	{LUA_COLIBNAME,   luaopen_coroutine},
	{LUA_TABLIBNAME,  luaopen_table},
	{LUA_STRLIBNAME,  luaopen_string},
	{LUA_MATHLIBNAME, luaopen_math},
	{LUA_UTF8LIBNAME, luaopen_utf8},
	{LUA_DBLIBNAME,   luaopen_debug},
// #if defined(LUA_COMPAT_BITLIB)
// 	{LUA_BITLIBNAME,  luaopen_bit32},
// #endif
	{NULL, NULL}
};

// moved from lua's lauxlib.c
typedef struct LoadS {
	const char *s;
	size_t size;
} LoadS;
static const char *getS (lua_State *L, void *ud, size_t *size) {
	LoadS *ls = (LoadS *)ud;
	(void)L;  /* not used */
	if (ls->size == 0) return NULL;
	*size = ls->size;
	ls->size = 0;
	return ls->s;
}
// moved from lua's liolib.c
static const luaL_Reg iolib[] = {
	{NULL, NULL}
};
static const luaL_Reg flib[] = {
	{NULL, NULL}
};
static void createmeta (lua_State *L) {
	luaL_newmetatable(L, LUA_FILEHANDLE);  /* create metatable for file handles */
	lua_pushvalue(L, -1);  /* push metatable */
	lua_setfield(L, -2, "__index");  /* metatable.__index = metatable */
	luaL_setfuncs(L, flib, 0);  /* add file methods to new metatable */
	lua_pop(L, 1);  /* pop new metatable */
}
LUAMOD_API int luaopen_io (lua_State *L) {
	luaL_newlib(L, iolib);  /* new module */
	createmeta(L);
	/* create (and set) default files */
	// createstdfile(L, stdin, IO_INPUT, "stdin");
	// createstdfile(L, stdout, IO_OUTPUT, "stdout");
	// createstdfile(L, stderr, NULL, "stderr");
	return 1;
}


LUALIB_API int luaL_loadbufferx (lua_State *L, const char *buff, size_t size,
                                 const char *name, const char *mode) {
	LoadS ls;
	ls.s = buff;
	ls.size = size;
	return lua_load(L, getS, &ls, name, mode);
}

int zen_load_string(lua_State *L, const char *code,
                    size_t size, const char *name) {
	int res;
#ifdef LUA_COMPILED
	res = luaL_loadbufferx(L,code,size,name,"b");
#else
	res = luaL_loadbufferx(L,code,size,name,NULL);
#endif
	switch (res) {
	case LUA_OK: { // func(L, "%s OK %s",__func__,name);
			break; }
	case LUA_ERRSYNTAX: { error(L, "%s syntax error: %s",__func__,name); break; }
	case LUA_ERRMEM: { error(L, "%s out of memory: %s",__func__, name); break;  }
	case LUA_ERRGCMM: {
		error(L, "%s garbage collection error: %s",__func__, name);
		break; }
	}
	// HEREn(size);
	// HEREp(code);
	return(res);
}

int zen_exec_extension(lua_State *L, zen_extension_t *p) {
	SAFE(p); HEREs(p->name);
	if(zen_load_string(L, p->code, *p->size, p->name)
	   ==LUA_OK) {
		// func(L,"%s %s", __func__, p->name);
		// HEREn(*p->size);
		// HEREp(p->code);
		lua_call(L,0,1);
		func(L,"loaded %s", p->name);
		return 1;
	}
	error(L, "%s", lua_tostring(L, -1));
	lerror(L,"%s %s",__func__,p->name); // quits with SIGABRT
	fflush(stderr);
	return 0;
}

int nop(lua_State *L) {
	lerror(L,"illegal instruction: require");
	return 0; }

int zen_require(lua_State *L) {
	SAFE(L);
	size_t len;
	const char *s = lua_tolstring(L, 1, &len);
	// HEREs(s);
	if(!s) return 0;
	// require classic lua libs
	for (luaL_Reg *p = lualibs;
	     p->name != NULL; ++p) {
		if (strcmp(p->name, s) == 0) {
			// HEREp(p->func);
			luaL_requiref(L, p->name, p->func, 1);
			// func(L,"%s %s",__func__, p->name);
			return 1;
		}
	}
	// SAFE(zen_extensions);
	zen_extension_t *p;
	// require our own lua extensions (generated by embed-lua)
	for (p = zen_extensions;
	     p->name != NULL; ++p) {
		// skip init (called as last)
		if (strcasecmp(p->name, s) == 0) {
			return zen_exec_extension(L,p);
		}
	}

	// require our own C to lua extensions
	if(strcasecmp(s, "octet")  ==0) {
		luaL_requiref(L, s, luaopen_octet, 1); }
	// else if(strcmp(s, "rsa")  ==0) {
	//  luaL_requiref(L, s, luaopen_rsa, 1);    return 1; }
	else if(strcasecmp(s, "ecdh")  ==0) {
		luaL_requiref(L, s, luaopen_ecdh, 1); }
	else if(strcasecmp(s, "ecp")  ==0) {
		luaL_requiref(L, s, luaopen_ecp, 1); }
	else if(strcasecmp(s, "ecp2")  ==0) {
		luaL_requiref(L, s, luaopen_ecp2, 1); }
	else if(strcasecmp(s, "big")  ==0) {
		luaL_requiref(L, s, luaopen_big, 1); }
	else if(strcasecmp(s, "fp12")  ==0) {
		luaL_requiref(L, s, luaopen_fp12, 1); }
	else if(strcasecmp(s, "rng")  ==0) {
		luaL_requiref(L, s, luaopen_rng, 1); }
	else if(strcasecmp(s, "hash")  ==0) {
		luaL_requiref(L, s, luaopen_hash, 1); }	
	else if(strcasecmp(s, "json")  ==0) {
		luaL_requiref(L, s, lua_cjson_safe_new, 1); }
	else if(strcasecmp(s, "msgpack")  ==0) {
		luaL_requiref(L, s, luaopen_cmsgpack_safe, 1); }
	else {
		// shall we bail out and abort execution here?
		warning(L, "required extension not found: %s",s);
		return 0; }
	func(L,"loaded %s",s);
	return 1;
}

int zen_require_override(lua_State *L, const int restricted) {
	static const struct luaL_Reg custom_require [] =
		{ {"require", zen_require },
		  {NULL, NULL} };
	static const struct luaL_Reg custom_require_restricted [] =
		{ {"require", nop },
		  {NULL, NULL} };

	lua_getglobal(L, "_G");
	if(restricted)
		luaL_setfuncs(L, custom_require_restricted, 0);
	else
		luaL_setfuncs(L, custom_require, 0);

	lua_pop(L, 1);
	return 1;
}

// load the src/lua/init.lua
int zen_lua_init(lua_State *L) {
	func(L, "loading lua initialisation");
	zen_extension_t *p;
	for (p = zen_extensions;
	     p->name != NULL; ++p) {
		if (strcasecmp(p->name, "init") == 0)
			return zen_exec_extension(L,p);
	}
	lua_gc(L, LUA_GCCOLLECT, 0);
	lua_gc(L, LUA_GCCOLLECT, 0);
	lerror(L,"Error loading lua init script");
	return 0;
}
