-- sample server
require'tango'

-- sample function
-- prints first level of table
-- and throws if argument is not of type 'table'
print_table = function(tab)
                if type(tab) == 'table' then
                  for k,v in pairs(tab) do
                    print(k,v)
                  end
                else
                  error('type_error')
                end
              end

-- starts the server on default port 12345
tango.serve()
