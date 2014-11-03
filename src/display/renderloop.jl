const SCREEN_STACK      = Screen[]

const RENDER_LIST       = Any[]
const SELECTION         = Dict{Symbol, Input{Matrix{Vector2{Int}}}}()
const SELECTION_QUERIES = Dict{Symbol, Rectangle{Int}}()

function insert_selectionquery!(name::Symbol, value::Rectangle)
  SELECTION_QUERIES[name] = value
  SELECTION[name]         = Input(Vector2{Int}[]')
  SELECTION[name]
end
function insert_selectionquery!(name::Symbol, value::Input{Rectangle})
  lift(value) do v
    SELECTION_QUERIES[name] = v
  end
  SELECTION[name]         = Input(Vector2{Int}[]')
  SELECTION[name]
end
function delete_selectionquery!(name::Symbol)
  delete!(SELECTION_QUERIES, name)
  delete!(SELECTION, name)
end

windowhints = [
  (GLFW.SAMPLES, 0), 
  (GLFW.DEPTH_BITS, 0), 
  (GLFW.ALPHA_BITS, 0), 
  (GLFW.STENCIL_BITS, 0),
  (GLFW.AUX_BUFFERS, 0)
]

const window = createwindow("Romeo", 1000, 800, windowhints=windowhints)
push!(SCREEN_STACK, window)
global pcamera  = PerspectiveCamera(window.inputs, Vec3(2), Vec3(0))
global ocamera  = OrthographicCamera(window.inputs)
global pocamera = OrthographicPixelCamera(window.inputs)



parameters = [
  (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
  (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE ),

  (GL_TEXTURE_MIN_FILTER, GL_NEAREST),
  (GL_TEXTURE_MAG_FILTER, GL_NEAREST) 
]

global const RENDER_FRAMEBUFFER = glGenFramebuffers()
glBindFramebuffer(GL_FRAMEBUFFER, RENDER_FRAMEBUFFER)

framebuffsize = [window.inputs[:framebuffer_size].value]

color   = Texture(RGBA{Ufixed8},     framebuffsize, parameters=parameters)
stencil = Texture(Vector2{GLushort}, framebuffsize, parameters=parameters)

glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, color.id, 0)
glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, stencil.id, 0)

rboDepthStencil = GLuint[0]

glGenRenderbuffers(1, rboDepthStencil)
glBindRenderbuffer(GL_RENDERBUFFER, rboDepthStencil[1])
glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT32, framebuffsize...)
glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, rboDepthStencil[1])

lift(window.inputs[:framebuffer_size]) do window_size
  resize!(color, window_size)
  resize!(stencil, window_size)
  glBindRenderbuffer(GL_RENDERBUFFER, rboDepthStencil[1])
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT32, (window_size)...)
end


function renderloop(window)
  global RENDER_LIST
  yield() 
  glBindFramebuffer(GL_FRAMEBUFFER, RENDER_FRAMEBUFFER)
  glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

  for elem in RENDER_LIST
     render(elem)
  end

  #Read all the selection queries
  if !isempty(SELECTION_QUERIES)
    glReadBuffer(GL_COLOR_ATTACHMENT1)
    for (key, value) in SELECTION_QUERIES
      const data = Array(Vector2{Uint16}, value.w, value.h)
      glReadPixels(value.x, value.y, value.w, value.h, stencil.format, stencil.pixeltype, data)
      push!(SELECTION[key], convert(Matrix{Vector2{Int}}, data))
    end
  end

  glReadBuffer(GL_COLOR_ATTACHMENT0)
  glBindFramebuffer(GL_READ_FRAMEBUFFER, RENDER_FRAMEBUFFER)
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0)
  glClear(GL_COLOR_BUFFER_BIT)

  window_size = window.inputs[:framebuffer_size].value
  glBlitFramebuffer(0,0, window_size..., 0,0, window_size..., GL_COLOR_BUFFER_BIT, GL_LINEAR)
  GLFW.SwapBuffers(window.nativewindow)
  GLFW.PollEvents()
end


glClearColor(39.0/255.0, 40.0/255.0, 34.0/255.0, 1.0)

if isinteractive()
@async begin 
  while window.inputs[:open].value
    renderloop(window)
  end 
  GLFW.Terminate()
end
else

end