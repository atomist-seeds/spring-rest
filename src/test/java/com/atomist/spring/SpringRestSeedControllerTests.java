package com.atomist.spring;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.context.junit4.SpringRunner;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@RunWith(SpringRunner.class)
@WebMvcTest(SpringRestSeedController.class)
public class SpringRestSeedControllerTests {

	@Autowired
	private MockMvc mockMvc;

	@Test
	public void shouldReturnGreeting() throws Exception {
		this.mockMvc.perform(get("/hello/Rod"))
				.andExpect(status().isOk())
				.andExpect(content().string(equalTo("Hello Rod!")));
	}

	@Test
	public void shouldReturnHello() throws Exception {
		this.mockMvc.perform(get("/"))
				.andExpect(status().isOk())
				.andExpect(content().string(startsWith("Hello")));
	}

	@Test
	public void shouldNotFindGreetingElsewhere() throws Exception {
		this.mockMvc.perform(get("/hey/man"))
				.andExpect(status().isNotFound());
	}

}
